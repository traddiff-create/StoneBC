package com.traddiff.stonebc.ui.screens.bikes

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.data.models.Bike
import com.traddiff.stonebc.ui.components.CategoryBadge
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun BikesScreen(onBikeTap: (String) -> Unit) {
    val state = LocalAppState.current
    val bikes = state.bikes

    var status by remember { mutableStateOf<String?>(null) }
    var type by remember { mutableStateOf<String?>(null) }

    val statuses = remember(bikes) { bikes.map { it.status }.distinct().sorted() }
    val types = remember(bikes) { bikes.map { it.type }.distinct().sorted() }

    val filtered = remember(bikes, status, type) {
        bikes.filter { (status == null || it.status == status) && (type == null || it.type == type) }
    }

    Column(modifier = Modifier.fillMaxSize().padding(top = BCSpacing.md)) {
        Header()
        ChipRow("Status", statuses, status) { status = if (status == it) null else it }
        Spacer(Modifier.height(BCSpacing.xs))
        ChipRow("Type", types, type) { type = if (type == it) null else it }
        Spacer(Modifier.height(BCSpacing.sm))

        if (filtered.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    "No bikes match those filters.",
                    fontSize = 13.sp,
                    color = Color.Gray
                )
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(BCSpacing.md),
                verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
            ) {
                items(filtered, key = { it.id }) { bike ->
                    BikeRow(bike = bike, onTap = { onBikeTap(bike.id) })
                }
            }
        }
    }
}

@Composable
private fun Header() {
    Column(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
        Text("The Quarry", fontSize = 22.sp, fontWeight = FontWeight.Light)
        Text(
            "Bikes looking for riders",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(Modifier.height(BCSpacing.sm))
    }
}

@Composable
private fun ChipRow(label: String, values: List<String>, selected: String?, onSelect: (String) -> Unit) {
    Column(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
        Text(
            label.uppercase(),
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            letterSpacing = 1.sp
        )
        Spacer(Modifier.height(4.dp))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs)) {
            items(values) { value ->
                FilterChip(
                    selected = selected == value,
                    onClick = { onSelect(value) },
                    label = { Text(value.replaceFirstChar { it.uppercase() }) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = BCColors.BrandBlue.copy(alpha = 0.2f),
                        selectedLabelColor = BCColors.BrandBlue
                    )
                )
            }
        }
    }
}

@Composable
private fun BikeRow(bike: Bike, onTap: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onTap)
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.xs)
    ) {
        Text(bike.model, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Row(horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs)) {
            CategoryBadge(category = bike.type)
            StatusBadge(status = bike.status)
            bike.sponsorPrice?.let {
                Text(
                    "$${it}",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = BCColors.BrandGreen
                )
            }
        }
        if (bike.description.isNotBlank()) {
            Text(
                bike.description,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun StatusBadge(status: String) {
    val color = when (status.lowercase()) {
        "available" -> BCColors.BrandGreen
        "refurbishing" -> BCColors.BrandAmber
        "sold" -> Color.Gray
        else -> Color.Gray
    }
    Text(
        text = status.replaceFirstChar { it.uppercase() },
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        color = Color.White,
        modifier = Modifier
            .background(color, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}
