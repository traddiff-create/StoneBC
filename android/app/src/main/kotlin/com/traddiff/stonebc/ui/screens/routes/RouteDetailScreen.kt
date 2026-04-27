package com.traddiff.stonebc.ui.screens.routes

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.data.models.Route
import com.traddiff.stonebc.ui.components.CategoryBadge
import com.traddiff.stonebc.ui.components.DifficultyBadge
import com.traddiff.stonebc.ui.components.ElevationProfileChart
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun RouteDetailScreen(routeId: String, onBack: () -> Unit, onStartRide: (String) -> Unit) {
    val state = LocalAppState.current
    val route = state.routes.firstOrNull { it.id == routeId }

    if (route == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(BCSpacing.md),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            BackHeader(onBack = onBack, title = "Route not found")
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = BCSpacing.xl)
    ) {
        BackHeader(onBack = onBack, title = route.name)
        Spacer(Modifier.height(BCSpacing.sm))
        StatsCard(route = route)
        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("Elevation Profile")
        Box(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
            ElevationProfileChart(trackpoints = route.trackpoints)
        }
        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("Map")
        Box(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
            RouteMapView(route = route, height = 260.dp)
        }
        Spacer(Modifier.height(BCSpacing.md))
        if (route.description.isNotBlank()) {
            SectionTitle("About")
            Text(
                text = route.description,
                fontSize = 14.sp,
                modifier = Modifier.padding(horizontal = BCSpacing.md, vertical = BCSpacing.xs)
            )
        }
        Spacer(Modifier.height(BCSpacing.lg))
        Button(
            onClick = { onStartRide(route.id) },
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = BCSpacing.md)
        ) {
            Text("Start Ride on This Route", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun BackHeader(onBack: () -> Unit, title: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.sm, vertical = BCSpacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            modifier = Modifier
                .clickable(onClick = onBack)
                .padding(BCSpacing.xs)
        )
        Spacer(Modifier.padding(horizontal = 4.dp))
        Text(text = title, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun StatsCard(route: Route) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.md)
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs)) {
            DifficultyBadge(difficulty = route.difficulty)
            CategoryBadge(category = route.category)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Stat(value = "${"%.1f".format(route.distanceMiles)}", label = "Miles")
            Stat(value = "${route.elevationGainFeet}", label = "Elevation ft")
            Stat(value = route.region, label = "Region")
        }
    }
}

@Composable
private fun Stat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(
            text = value,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = BCColors.BrandBlue
        )
        Text(
            text = label,
            fontSize = 10.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text.uppercase(),
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        letterSpacing = 1.sp,
        modifier = Modifier.padding(horizontal = BCSpacing.md, vertical = BCSpacing.xs)
    )
}
