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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Article
import androidx.compose.material.icons.automirrored.filled.NavigateNext
import androidx.compose.material.icons.filled.Backpack
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.OpenInBrowser
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.School
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.ui.components.DisabledFeatureCard
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun MoreScreen(onNavigate: (String) -> Unit) {
    val state = LocalAppState.current
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(bottom = BCSpacing.xl))
    ) {
        SectionTitle("Community")
        NavRow(Icons.AutoMirrored.Filled.Article, "Community Feed", "${state.posts.size} posts") { onNavigate("community") }
        NavRow(Icons.Default.Event, "Events", "${state.events.size} upcoming") { onNavigate("events") }
        NavRow(Icons.Default.School, "Programs", "${state.programs.size} offerings") { onNavigate("programs") }
        NavRow(Icons.Default.Image, "Gallery", "${state.photos.size} photos") { onNavigate("gallery") }

        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("Rides & Trips")
        NavRow(Icons.Default.Backpack, "Tour Guides", "${state.tourGuides.size} guides") { onNavigate("guides") }
        NavRow(Icons.Default.Book, "Expedition Journal", "Lewis & Clark–style ride docs") { onNavigate("expeditions") }
        NavRow(Icons.Default.Build, "Swiss Army Knife", "Weather, trails, emergency, sync") { onNavigate("swiss") }

        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("Get Involved")
        NavRow(Icons.Default.Favorite, "Volunteer", "Time · Talent · Treasure") { onNavigate("volunteer") }
        NavRow(Icons.Default.Redeem, "Donate", "Bikes · Parts · Funds") { onNavigate("donate") }

        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("iOS Only")
        DisabledFeatureCard(
            title = "Rally Radio",
            subtitle = "Peer-to-peer voice chat — iOS exclusive (MultipeerConnectivity)",
            modifier = Modifier.padding(horizontal = BCSpacing.md)
        )

        Spacer(Modifier.height(BCSpacing.md))
        SectionTitle("Links")
        LinkRow(Icons.Default.OpenInBrowser, "stonebicyclecoalition.com") {
            openUrl(context, state.config.websiteURL)
        }
        LinkRow(Icons.Default.OpenInBrowser, "traddiff.com") {
            openUrl(context, "https://traddiff.com")
        }
        Spacer(Modifier.height(BCSpacing.md))
        Text(
            text = "${state.config.coalitionName} · v0.87",
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = BCSpacing.md)
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
        modifier = Modifier.padding(horizontal = BCSpacing.md, vertical = BCSpacing.sm)
    )
}

@Composable
private fun NavRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = BCSpacing.md, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = BCColors.BrandBlue)
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 15.sp, fontWeight = FontWeight.Medium)
            Text(
                subtitle,
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.NavigateNext,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun LinkRow(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = BCSpacing.md, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = BCColors.BrandBlue)
        Text(label, fontSize = 14.sp, color = BCColors.BrandBlue)
    }
}

private fun openUrl(context: android.content.Context, url: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        context.startActivity(intent)
    }
}
