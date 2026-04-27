package com.traddiff.stonebc.ui.screens.record

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.traddiff.stonebc.data.GPXExporter
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.data.models.Route
import com.traddiff.stonebc.data.models.RouteRecordingMode
import com.traddiff.stonebc.services.RecordingService
import com.traddiff.stonebc.storage.RideEntry
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun RecordScreen(initialRouteId: String? = null, onNavigateToRides: () -> Unit = {}) {
    val context = LocalContext.current
    val appState = LocalAppState.current
    val coroutineScope = rememberCoroutineScope()
    val session by RecordingService.sessionFlow.collectAsState()
    val routes = appState.routes

    var selectedMode by remember(initialRouteId) {
        mutableStateOf(if (initialRouteId != null) RouteRecordingMode.follow else RouteRecordingMode.free)
    }
    var selectedRouteId by remember(initialRouteId) { mutableStateOf(initialRouteId) }
    val selectedRoute = routes.firstOrNull { it.id == selectedRouteId }
    val canStart = selectedMode != RouteRecordingMode.follow || selectedRoute != null

    var permissionGranted by remember { mutableStateOf(hasLocationPermission(context)) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        permissionGranted = results.values.all { it }
        if (permissionGranted && canStart) {
            RecordingService.start(
                context = context,
                mode = selectedMode,
                routeId = selectedRoute?.id,
                routeName = selectedRoute?.name,
                routeCategory = selectedRoute?.category
            )
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(BCSpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(BCSpacing.md)
    ) {
        if (session != null) {
            ActiveRideHero(session = session!!)
            StopRideButton(
                onStop = {
                    session?.let { saved ->
                        coroutineScope.launch {
                            appState.rideHistoryStore.addRide(
                                RideEntry(
                                    id = saved.id,
                                    date = today(),
                                    routeName = saved.routeName ?: rideLabel(saved.recordingMode),
                                    category = saved.routeCategory ?: "road",
                                    distanceMiles = saved.distanceMiles,
                                    elevationGainFeet = saved.elevationGainFeet,
                                    durationSeconds = saved.durationSeconds,
                                    avgSpeedMph = if (saved.durationSeconds > 0)
                                        saved.distanceMiles / (saved.durationSeconds / 3600.0) else 0.0,
                                    maxSpeedMph = saved.trackpoints
                                        .mapNotNull { it.speedMetersPerSecond }
                                        .maxOrNull()
                                        ?.toDouble()?.times(2.23694) ?: 0.0,
                                    routeId = saved.routeId,
                                    gpxTrackpoints = saved.trackpoints
                                        .map { listOf(it.latitude, it.longitude, it.elevationMeters ?: 0.0) }
                                        .takeIf { it.size >= 2 }
                                )
                            )
                            writeGpxToCache(context, saved, "stonebc-${saved.id}.gpx")
                        }
                    }
                    RecordingService.stop(context)
                    RecordingService.clearSession()
                }
            )
        } else {
            StartRideButton(
                enabled = canStart,
                mode = selectedMode,
                selectedRoute = selectedRoute,
                onStart = {
                    if (permissionGranted) {
                        RecordingService.start(
                            context = context,
                            mode = selectedMode,
                            routeId = selectedRoute?.id,
                            routeName = selectedRoute?.name,
                            routeCategory = selectedRoute?.category
                        )
                    } else {
                        permissionLauncher.launch(requiredPermissions())
                    }
                }
            )
            RecordingModeSection(selectedMode = selectedMode) { mode ->
                selectedMode = mode
                if (mode != RouteRecordingMode.follow) selectedRouteId = null
            }
            if (selectedMode == RouteRecordingMode.follow) {
                RoutePicker(
                    routes = routes.take(12),
                    selectedRouteId = selectedRouteId,
                    onSelect = { selectedRouteId = it.id }
                )
            }
        }

        Spacer(Modifier.height(BCSpacing.sm))
        Button(
            onClick = onNavigateToRides,
            colors = ButtonDefaults.outlinedButtonColors(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("MY RIDES →", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun rememberCoroutineScope() = androidx.compose.runtime.rememberCoroutineScope()

@Composable
private fun StartRideButton(
    enabled: Boolean,
    mode: RouteRecordingMode,
    selectedRoute: Route?,
    onStart: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .padding(BCSpacing.lg),
        contentAlignment = Alignment.Center
    ) {
        Button(
            onClick = onStart,
            enabled = enabled,
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.NavAlertRed),
            modifier = Modifier.size(220.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (enabled) "START" else "CHOOSE", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color.White)
                Text(if (enabled) "RIDE" else "ROUTE", fontSize = 18.sp, color = Color.White)
                val subtitle = selectedRoute?.name ?: mode.label
                Text(subtitle, fontSize = 11.sp, color = Color.White.copy(alpha = 0.85f), maxLines = 2)
            }
        }
    }
}

@Composable
private fun RecordingModeSection(
    selectedMode: RouteRecordingMode,
    onSelect: (RouteRecordingMode) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        SectionLabel("Recording Mode")
        RouteRecordingMode.entries.forEach { mode ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        if (selectedMode == mode) BCColors.BrandBlue.copy(alpha = 0.12f)
                        else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                        RoundedCornerShape(12.dp)
                    )
                    .clickable { onSelect(mode) }
                    .padding(BCSpacing.md),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(mode.label, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                    Text(mode.subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (selectedMode == mode) {
                    Text("Selected", fontSize = 11.sp, color = BCColors.BrandBlue, fontWeight = FontWeight.Medium)
                }
            }
        }
    }
}

@Composable
private fun RoutePicker(routes: List<Route>, selectedRouteId: String?, onSelect: (Route) -> Unit) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
        SectionLabel("Follow Route")
        if (routes.isEmpty()) {
            Text("Routes are still loading.", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            return
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
            items(routes, key = { it.id }) { route ->
                Column(
                    modifier = Modifier
                        .width(160.dp)
                        .background(
                            if (selectedRouteId == route.id) BCColors.BrandBlue.copy(alpha = 0.12f)
                            else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                        .clickable { onSelect(route) }
                        .padding(BCSpacing.sm),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(route.name, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, maxLines = 2)
                    Text(
                        "%.1f mi · ${route.difficulty}".format(route.distanceMiles),
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    if (selectedRouteId == route.id) {
                        Text("Selected", fontSize = 10.sp, color = BCColors.BrandBlue, fontWeight = FontWeight.Medium)
                    }
                }
            }
        }
    }
}

@Composable
private fun StopRideButton(onStop: () -> Unit) {
    Button(
        onClick = onStop,
        colors = ButtonDefaults.buttonColors(containerColor = BCColors.NavAlertRed),
        modifier = Modifier.fillMaxWidth()
    ) {
        Text("END RIDE", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
    }
}

@Composable
private fun ActiveRideHero(session: com.traddiff.stonebc.data.models.RideSession) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(16.dp)
            )
            .padding(BCSpacing.lg),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        Text(
            text = "%.1f".format(session.currentSpeedMph),
            fontSize = 80.sp,
            fontWeight = FontWeight.Light,
            color = BCColors.BrandBlue
        )
        Text(text = "mph", fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatCell(value = "%.2f".format(session.distanceMiles), label = "Miles")
            StatCell(value = session.elevationGainFeet.toString(), label = "Elev ft")
            StatCell(value = formatDuration(session.durationSeconds), label = "Time")
        }
        if (session.isPaused) {
            Text(
                text = "Auto-paused",
                color = BCColors.NavAlertAmber,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun StatCell(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(text = value, fontSize = 20.sp, fontWeight = FontWeight.SemiBold)
        Text(text = label, fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

private fun formatDuration(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

private fun rideLabel(mode: RouteRecordingMode): String = when (mode) {
    RouteRecordingMode.free -> "Recorded Ride"
    RouteRecordingMode.follow -> "Followed Route"
    RouteRecordingMode.scout -> "Scouted Route"
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        letterSpacing = 1.sp,
        modifier = Modifier.fillMaxWidth()
    )
}

private fun requiredPermissions(): Array<String> {
    val base = mutableListOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION
    )
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        base += Manifest.permission.POST_NOTIFICATIONS
    }
    return base.toTypedArray()
}

private fun hasLocationPermission(context: android.content.Context): Boolean =
    ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED

private fun writeGpxToCache(context: android.content.Context, session: com.traddiff.stonebc.data.models.RideSession, fileName: String) {
    runCatching {
        val file = File(context.cacheDir, fileName)
        file.writeText(GPXExporter.toGPX(session))
    }.onFailure { android.util.Log.w("RecordScreen", "GPX write failed", it) }
}
