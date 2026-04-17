package com.traddiff.stonebc.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.dp
import com.traddiff.stonebc.ui.theme.BCColors

/**
 * Renders a minimal elevation profile from trackpoints shaped as [lat, lon, elevation].
 * Distance on X axis is approximated by haversine summation; elevation on Y axis.
 */
@Composable
fun ElevationProfileChart(
    trackpoints: List<List<Double>>,
    modifier: Modifier = Modifier,
    lineColor: Color = BCColors.BrandBlue,
    fillColor: Color = BCColors.BrandBlue.copy(alpha = 0.12f)
) {
    if (trackpoints.size < 2) return

    val elevations = trackpoints.mapNotNull { it.getOrNull(2) }
    if (elevations.isEmpty()) return

    val minEle = elevations.min()
    val maxEle = elevations.max()
    val eleRange = (maxEle - minEle).coerceAtLeast(1.0)

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(140.dp)
    ) {
        val step = size.width / (elevations.size - 1).coerceAtLeast(1)
        val path = Path()
        val fillPath = Path()

        elevations.forEachIndexed { index, elevation ->
            val x = index * step
            val normalized = ((elevation - minEle) / eleRange).toFloat()
            val y = size.height - (normalized * size.height * 0.9f) - (size.height * 0.05f)
            if (index == 0) {
                path.moveTo(x, y)
                fillPath.moveTo(x, size.height)
                fillPath.lineTo(x, y)
            } else {
                path.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
        }
        fillPath.lineTo(size.width, size.height)
        fillPath.close()

        drawPath(path = fillPath, color = fillColor)
        drawPath(
            path = path,
            color = lineColor,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3f)
        )

        // Baseline
        drawLine(
            color = Color.Gray.copy(alpha = 0.3f),
            start = Offset(0f, size.height),
            end = Offset(size.width, size.height),
            strokeWidth = 1f
        )
    }
}
