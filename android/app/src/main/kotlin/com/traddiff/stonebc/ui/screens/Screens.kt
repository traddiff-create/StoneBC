package com.traddiff.stonebc.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Phase 1 placeholders. Each tab gets its own file in Phase 2+.
 * This keeps the initial scaffold compile+boot verifiable with zero
 * domain dependencies.
 */

@Composable
fun RoutesScreen() = PlaceholderScreen("Routes", "56 curated routes loaded from routes.json — Phase 3.")

@Composable
fun RecordScreen() = PlaceholderScreen("Record", "GPS recording with 7 s auto-pause — Phase 4.")

@Composable
fun BikesScreen() = PlaceholderScreen("Bikes", "The Quarry marketplace — Phase 5.")

@Composable
fun MoreScreen() = PlaceholderScreen("More", "Community · Events · Expeditions · Contact — Phase 5+.")

@Composable
private fun PlaceholderScreen(title: String, subtitle: String) {
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(title, fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(subtitle, fontSize = 14.sp)
    }
}
