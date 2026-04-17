package com.traddiff.stonebc.ui.screens.more

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudQueue
import androidx.compose.material.icons.filled.Forest
import androidx.compose.material.icons.filled.LocalHospital
import androidx.compose.material.icons.filled.Pool
import androidx.compose.material.icons.filled.Terrain
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun SwissArmyKnifeScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        BackHeader(onBack, "Swiss Army Knife")

        Text(
            "Companion services for every ride. Emergency call is live now; " +
                "Strava, Trailforks, USFS, and Weather sync is wired into " +
                "iOS and will connect on Android when the shared keys ship.",
            fontSize = 13.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(BCSpacing.md)
        )

        ToolRow(
            icon = Icons.Default.LocalHospital,
            tint = BCColors.NavAlertRed,
            title = "Emergency Call",
            subtitle = "Dials 911 via system dialer. Android ELS shares your location.",
            onTap = {
                runCatching {
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:911"))
                    context.startActivity(intent)
                }
            }
        )

        ToolRow(
            icon = Icons.Default.CloudQueue,
            tint = BCColors.BrandBlue,
            title = "Weather (OpenWeatherMap)",
            subtitle = "Forecast for the region around each route. iOS key reuse pending.",
            onTap = null
        )

        ToolRow(
            icon = Icons.Default.Terrain,
            tint = BCColors.BrandGreen,
            title = "Trail Conditions (Trailforks)",
            subtitle = "Crowdsourced trail status with 4-hour cache. Awaiting Android key.",
            onTap = null
        )

        ToolRow(
            icon = Icons.Default.Forest,
            tint = BCColors.BrandGreen,
            title = "USFS Closures (ArcGIS)",
            subtitle = "Black Hills NF road and trail closures from the public feed.",
            onTap = null
        )

        ToolRow(
            icon = Icons.Default.Pool,
            tint = BCColors.BrandAmber,
            title = "Strava Sync",
            subtitle = "OAuth2 via AppAuth — Android redirect URI to be registered in Strava.",
            onTap = null
        )
    }
}

@Composable
private fun ToolRow(
    icon: ImageVector,
    tint: Color,
    title: String,
    subtitle: String,
    onTap: (() -> Unit)?
) {
    val rowMod = Modifier
        .fillMaxWidth()
        .padding(horizontal = BCSpacing.md, vertical = 4.dp)
        .let { if (onTap != null) it.clickable(onClick = onTap) else it }
        .background(
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = if (onTap != null) 0.4f else 0.2f),
            RoundedCornerShape(12.dp)
        )
        .padding(BCSpacing.md)

    Row(modifier = rowMod, verticalAlignment = Alignment.CenterVertically) {
        Icon(imageVector = icon, contentDescription = null, tint = tint)
        Spacer(Modifier.width(12.dp))
        Column {
            Text(
                text = title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (onTap == null) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                else MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = if (onTap == null) "$subtitle · coming soon" else subtitle,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

