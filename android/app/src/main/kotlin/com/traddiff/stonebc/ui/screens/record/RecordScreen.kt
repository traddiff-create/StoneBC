package com.traddiff.stonebc.ui.screens.record

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
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
fun RecordScreen() {
    val context = LocalContext.current
    val appState = LocalAppState.current
    val coroutineScope = rememberCoroutineScope()
    val session by RecordingService.sessionFlow.collectAsState()
    val history by appState.rideHistoryStore.entries.collectAsState(initial = emptyList())

    var permissionGranted by remember { mutableStateOf(hasLocationPermission(context)) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        permissionGranted = results.values.all { it }
        if (permissionGranted) RecordingService.start(context)
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
                                    distanceMiles = saved.distanceMiles,
                                    elevationGainFeet = saved.elevationGainFeet,
                                    durationSeconds = saved.durationSeconds
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
                onStart = {
                    if (permissionGranted) {
                        RecordingService.start(context)
                    } else {
                        permissionLauncher.launch(requiredPermissions())
                    }
                }
            )
        }

        Spacer(Modifier.height(BCSpacing.sm))
        RideHistorySection(history = history)
    }
}

@Composable
private fun rememberCoroutineScope() = androidx.compose.runtime.rememberCoroutineScope()

@Composable
private fun StartRideButton(onStart: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .padding(BCSpacing.lg),
        contentAlignment = Alignment.Center
    ) {
        Button(
            onClick = onStart,
            shape = CircleShape,
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.NavAlertRed),
            modifier = Modifier.size(220.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("START", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color.White)
                Text("RIDE", fontSize = 18.sp, color = Color.White)
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

@Composable
private fun RideHistorySection(history: List<RideEntry>) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "RECENT RIDES",
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 1.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(BCSpacing.xs))
        if (history.isEmpty()) {
            Text(
                text = "Your first ride will appear here.",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(vertical = BCSpacing.sm)
            )
        } else {
            history.takeLast(5).reversed().forEach { entry ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(entry.date, fontSize = 13.sp)
                    Text(
                        "${"%.2f".format(entry.distanceMiles)} mi · ${entry.elevationGainFeet} ft",
                        fontSize = 13.sp,
                        color = BCColors.BrandBlue
                    )
                }
            }
        }
    }
}

private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

private fun formatDuration(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
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
