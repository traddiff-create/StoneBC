package com.traddiff.stonebc.ui.screens.rides

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.traddiff.stonebc.ui.theme.BCColors

@Composable
fun RideMiniMapView(trackpoints: List<List<Double>>, modifier: Modifier = Modifier) {
    if (trackpoints.size < 2) {
        Box(
            modifier = modifier.background(BCColors.BrandBlue.copy(alpha = 0.08f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                Icons.AutoMirrored.Filled.DirectionsBike,
                contentDescription = null,
                tint = BCColors.BrandBlue.copy(alpha = 0.7f)
            )
        }
        return
    }

    val lats = trackpoints.mapNotNull { it.getOrNull(0) }
    val lons = trackpoints.mapNotNull { it.getOrNull(1) }
    val minLat = lats.min()
    val maxLat = lats.max()
    val minLon = lons.min()
    val maxLon = lons.max()
    val brandBlue = BCColors.BrandBlue

    Canvas(modifier = modifier.background(Color(0xFF1A1A2E))) {
        val latRange = (maxLat - minLat).coerceAtLeast(0.001)
        val lonRange = (maxLon - minLon).coerceAtLeast(0.001)
        val padding = size.minDimension * 0.1f
        val drawWidth = size.width - 2 * padding
        val drawHeight = size.height - 2 * padding

        fun toOffset(lat: Double, lon: Double): Offset {
            val x = padding + ((lon - minLon) / lonRange * drawWidth).toFloat()
            val y = padding + ((maxLat - lat) / latRange * drawHeight).toFloat()
            return Offset(x, y)
        }

        val path = Path()
        trackpoints.forEachIndexed { i, pt ->
            val lat = pt.getOrNull(0) ?: return@forEachIndexed
            val lon = pt.getOrNull(1) ?: return@forEachIndexed
            val offset = toOffset(lat, lon)
            if (i == 0) path.moveTo(offset.x, offset.y) else path.lineTo(offset.x, offset.y)
        }
        drawPath(path = path, color = brandBlue, style = Stroke(width = 2f))

        trackpoints.first().let { pt ->
            val (lat, lon) = pt[0] to pt[1]
            drawCircle(Color(0xFF22C55E), radius = 4.dp.toPx(), center = toOffset(lat, lon))
        }
        trackpoints.last().let { pt ->
            val (lat, lon) = pt[0] to pt[1]
            drawCircle(Color(0xFFEF4444), radius = 4.dp.toPx(), center = toOffset(lat, lon))
        }
    }
}
