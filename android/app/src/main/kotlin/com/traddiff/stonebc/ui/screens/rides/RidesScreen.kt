package com.traddiff.stonebc.ui.screens.rides

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.storage.AllTimeSummary
import com.traddiff.stonebc.storage.PersonalRecords
import com.traddiff.stonebc.storage.RideEntry
import com.traddiff.stonebc.storage.monthlyMiles
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RidesScreen(onBack: () -> Unit) {
    val appState = LocalAppState.current
    val entries by appState.rideHistoryStore.entries.collectAsState(initial = emptyList())
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("History", "Stats")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("My Rides", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(modifier = Modifier.padding(innerPadding).fillMaxSize()) {
            ScrollableTabRow(
                selectedTabIndex = selectedTab,
                edgePadding = 0.dp
            ) {
                tabs.forEachIndexed { index, title ->
                    Tab(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        text = { Text(title) }
                    )
                }
            }
            when (selectedTab) {
                0 -> HistoryTab(entries)
                1 -> StatsTab(entries)
            }
        }
    }
}

@Composable
private fun HistoryTab(entries: List<RideEntry>) {
    if (entries.isEmpty()) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(
                "Record your first ride to see it here.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                fontSize = 14.sp
            )
        }
        return
    }
    LazyColumn(
        contentPadding = PaddingValues(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        items(entries.reversed()) { entry ->
            RideRow(entry)
        }
    }
}

@Composable
private fun RideRow(entry: RideEntry) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
            .padding(BCSpacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val trackpoints = entry.gpxTrackpoints ?: emptyList()
        RideMiniMapView(
            trackpoints = trackpoints,
            modifier = Modifier
                .size(56.dp)
                .clip(RoundedCornerShape(8.dp))
        )
        Spacer(Modifier.width(BCSpacing.sm))
        Column(modifier = Modifier.weight(1f)) {
            Text(entry.routeName, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1)
            Text(entry.date, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("%.2f mi".format(entry.distanceMiles), fontSize = 13.sp, fontWeight = FontWeight.Medium)
            Text(formatDuration(entry.durationSeconds), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun StatsTab(entries: List<RideEntry>) {
    val summary = AllTimeSummary.from(entries)
    val prs = PersonalRecords.from(entries)
    val monthly = monthlyMiles(entries)

    LazyColumn(
        contentPadding = PaddingValues(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.md)
    ) {
        item { AllTimeCard(summary) }
        item { PRGrid(prs) }
        item { MonthlyChart(monthly) }
        item { CategoryBreakdown(entries) }
    }
}

@Composable
private fun AllTimeCard(summary: AllTimeSummary) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(BCColors.BrandBlue.copy(alpha = 0.1f), RoundedCornerShape(12.dp))
            .padding(BCSpacing.md),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        SummaryCell("%.1f".format(summary.totalMiles), "Total Miles")
        SummaryCell(summary.rideCount.toString(), "Rides")
        SummaryCell("%,d".format(summary.totalElevationFeet), "Elev ft")
    }
}

@Composable
private fun SummaryCell(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = BCColors.BrandBlue)
        Text(label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun PRGrid(prs: PersonalRecords) {
    Column(modifier = Modifier.fillMaxWidth()) {
        SectionLabel("PERSONAL RECORDS")
        Spacer(Modifier.height(BCSpacing.xs))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
            PRCard("Longest Ride", "%.2f mi".format(prs.longestMiles), Modifier.weight(1f))
            PRCard("Fastest Avg", "%.1f mph".format(prs.fastestAvgMph), Modifier.weight(1f))
        }
        Spacer(Modifier.height(BCSpacing.sm))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
            PRCard("Most Elevation", "%,d ft".format(prs.mostElevationFeet), Modifier.weight(1f))
            PRCard("Best Streak", "${prs.longestStreakDays} days", Modifier.weight(1f))
        }
    }
}

@Composable
private fun PRCard(label: String, value: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f), RoundedCornerShape(10.dp))
            .padding(BCSpacing.sm),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(value, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun MonthlyChart(monthly: List<Pair<String, Double>>) {
    val maxMiles = monthly.maxOfOrNull { it.second }?.coerceAtLeast(1.0) ?: 1.0
    val brandBlue = BCColors.BrandBlue

    Column(modifier = Modifier.fillMaxWidth()) {
        SectionLabel("MONTHLY MILES")
        Spacer(Modifier.height(BCSpacing.sm))
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
        ) {
            val barCount = monthly.size
            val totalSpacing = size.width * 0.1f
            val barWidth = (size.width - totalSpacing) / barCount
            val gap = totalSpacing / (barCount + 1)

            monthly.forEachIndexed { i, (_, miles) ->
                val barHeight = (miles / maxMiles * size.height * 0.85f).toFloat()
                val x = gap + i * (barWidth + gap)
                val y = size.height - barHeight
                drawRoundRect(
                    color = brandBlue.copy(alpha = if (miles > 0) 1f else 0.15f),
                    topLeft = Offset(x, y),
                    size = Size(barWidth, barHeight),
                    cornerRadius = CornerRadius(4f, 4f)
                )
            }
        }
        Row(
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            monthly.forEach { (label, _) ->
                Text(label, fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun CategoryBreakdown(entries: List<RideEntry>) {
    if (entries.isEmpty()) return
    val byCategory = entries.groupBy { it.category.replaceFirstChar { c -> c.uppercase() } }
        .mapValues { (_, list) -> list.sumOf { it.distanceMiles } }
        .entries.sortedByDescending { it.value }
    val totalMiles = byCategory.sumOf { it.value }.coerceAtLeast(0.001)
    val brandBlue = BCColors.BrandBlue

    Column(modifier = Modifier.fillMaxWidth()) {
        SectionLabel("BY CATEGORY")
        Spacer(Modifier.height(BCSpacing.xs))
        byCategory.forEach { (cat, miles) ->
            val fraction = (miles / totalMiles).toFloat()
            Column(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(cat, fontSize = 13.sp)
                    Text("%.1f mi · %d%%".format(miles, (fraction * 100).toInt()), fontSize = 13.sp)
                }
                Spacer(Modifier.height(3.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(6.dp)
                        .background(brandBlue.copy(alpha = 0.1f), RoundedCornerShape(3.dp))
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(fraction)
                            .height(6.dp)
                            .background(brandBlue, RoundedCornerShape(3.dp))
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        letterSpacing = 1.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

private fun formatDuration(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
