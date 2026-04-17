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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.data.models.Route
import com.traddiff.stonebc.data.repositories.RoutesRepository
import com.traddiff.stonebc.ui.components.CategoryBadge
import com.traddiff.stonebc.ui.components.DifficultyBadge
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun RoutesScreen(onRouteTap: (String) -> Unit) {
    val appState = LocalAppState.current
    val repository = remember { RoutesRepository() }

    var query by remember { mutableStateOf("") }
    var difficulty by remember { mutableStateOf<String?>(null) }
    var category by remember { mutableStateOf<String?>(null) }

    val routes = appState.routes
    val difficulties = remember(routes) { repository.availableDifficulties(routes) }
    val categories = remember(routes) { repository.availableCategories(routes) }
    val filtered = remember(routes, query, difficulty, category) {
        repository.filter(routes, query, difficulty, category)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = BCSpacing.md)
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { Text("Search routes") },
            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = BCSpacing.md)
        )

        Spacer(Modifier.height(BCSpacing.sm))

        ChipRow(
            label = "Difficulty",
            values = difficulties,
            selected = difficulty,
            onSelect = { difficulty = if (difficulty == it) null else it }
        )

        Spacer(Modifier.height(BCSpacing.xs))

        ChipRow(
            label = "Category",
            values = categories,
            selected = category,
            onSelect = { category = if (category == it) null else it }
        )

        Spacer(Modifier.height(BCSpacing.sm))

        if (filtered.isEmpty()) {
            EmptyState(hasRoutes = routes.isNotEmpty())
        } else {
            LazyColumn(
                contentPadding = PaddingValues(
                    start = BCSpacing.md,
                    end = BCSpacing.md,
                    bottom = BCSpacing.xl
                ),
                verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
            ) {
                items(filtered, key = { it.id }) { route ->
                    RouteRow(route = route, onTap = { onRouteTap(route.id) })
                }
            }
        }
    }
}

@Composable
private fun ChipRow(
    label: String,
    values: List<String>,
    selected: String?,
    onSelect: (String) -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
        Text(
            text = label.uppercase(),
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
private fun RouteRow(route: Route, onTap: () -> Unit) {
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
        Text(
            text = route.name,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            DifficultyBadge(difficulty = route.difficulty)
            CategoryBadge(category = route.category)
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(BCSpacing.md)
        ) {
            StatLabel(value = "${"%.1f".format(route.distanceMiles)} mi", label = "Distance")
            StatLabel(value = "${route.elevationGainFeet} ft", label = "Elevation")
            StatLabel(value = route.region, label = "Region")
        }
        if (route.description.isNotBlank()) {
            Text(
                text = route.description,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun StatLabel(value: String, label: String) {
    Column {
        Text(
            text = value,
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
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
private fun EmptyState(hasRoutes: Boolean) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(BCSpacing.lg),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = if (hasRoutes) "No routes match those filters." else "Loading routes…",
            fontSize = 13.sp,
            color = Color.Gray
        )
    }
}
