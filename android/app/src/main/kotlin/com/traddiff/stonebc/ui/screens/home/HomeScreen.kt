package com.traddiff.stonebc.ui.screens.home

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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Map
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.data.models.Bike
import com.traddiff.stonebc.data.models.Post
import com.traddiff.stonebc.ui.components.CategoryBadge
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun HomeScreen() {
    val state = LocalAppState.current

    LaunchedEffect(Unit) {
        if (state.isLoading) state.load()
    }

    // Render immediately — each section handles its own empty/loading state
    // so other tabs don't get blocked behind the 3.9MB routes decode.
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(bottom = BCSpacing.xl)),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.lg)
    ) {
        HeroSection(
            title = state.config.coalitionName,
            tagline = state.config.tagline
        )
        SeasonSummaryCard()
        QuickLinks()
        if (state.featuredBikes.isNotEmpty()) {
            FeaturedBikesRow(state.featuredBikes)
        }
        if (state.recentPosts.isNotEmpty()) {
            RecentPostsColumn(state.recentPosts)
        }
        Footer(state.config.websiteURL)
    }
}

@Composable
private fun HeroSection(title: String, tagline: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.md, vertical = BCSpacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .background(BCColors.BrandBlue, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.DirectionsBike,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(36.dp)
            )
        }
        Text(
            text = title,
            fontSize = 28.sp,
            fontWeight = FontWeight.Light,
            color = MaterialTheme.colorScheme.onBackground
        )
        Text(
            text = tagline,
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f)
        )
    }
}

@Composable
private fun SeasonSummaryCard() {
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
        SectionTitle("Your Season")
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            SummaryStat(value = "0", label = "Rides")
            SummaryStat(value = "0", label = "Miles")
            SummaryStat(value = "0", label = "Elevation ft")
        }
        Text(
            text = "Start recording on the Record tab — your season summary fills in automatically.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun SummaryStat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            fontSize = 24.sp,
            fontWeight = FontWeight.SemiBold,
            color = BCColors.BrandBlue
        )
        Text(
            text = label,
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun QuickLinks() {
    Column(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
        SectionTitle("Quick Links")
        Spacer(Modifier.height(BCSpacing.sm))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
            items(quickLinkData) { link ->
                QuickLinkTile(icon = link.icon, label = link.label)
            }
        }
    }
}

private data class QuickLink(val icon: ImageVector, val label: String)

private val quickLinkData = listOf(
    QuickLink(Icons.Default.Map, "Routes"),
    QuickLink(Icons.Default.FiberManualRecord, "Record"),
    QuickLink(Icons.AutoMirrored.Filled.DirectionsBike, "Bikes"),
    QuickLink(Icons.Default.Event, "Events"),
    QuickLink(Icons.Default.Image, "Gallery")
)

@Composable
private fun QuickLinkTile(icon: ImageVector, label: String) {
    Column(
        modifier = Modifier
            .width(96.dp)
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .padding(BCSpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(BCSpacing.xs)
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = BCColors.BrandBlue)
        Text(text = label, fontSize = 12.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun FeaturedBikesRow(bikes: List<Bike>) {
    Column(modifier = Modifier.padding(horizontal = BCSpacing.md)) {
        SectionTitle("Featured Bikes in The Quarry")
        Spacer(Modifier.height(BCSpacing.sm))
        LazyRow(horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
            items(bikes) { bike -> FeaturedBikeCard(bike) }
        }
    }
}

@Composable
private fun FeaturedBikeCard(bike: Bike) {
    Column(
        modifier = Modifier
            .width(220.dp)
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.xs)
    ) {
        Text(
            text = bike.model,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1
        )
        Row(horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs)) {
            CategoryBadge(category = bike.type)
            if (bike.sponsorPrice != null) {
                Text(
                    text = "$${bike.sponsorPrice}",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = BCColors.BrandGreen
                )
            }
        }
        Text(
            text = bike.description,
            fontSize = 12.sp,
            maxLines = 2,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun RecentPostsColumn(posts: List<Post>) {
    Column(
        modifier = Modifier.padding(horizontal = BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
    ) {
        SectionTitle("Recent Posts")
        posts.forEach { post -> RecentPostCard(post) }
    }
}

@Composable
private fun RecentPostCard(post: Post) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(BCSpacing.xs)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = post.category.uppercase(),
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = BCColors.BrandBlue,
                modifier = Modifier
                    .background(BCColors.BrandBlue.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )
            Spacer(Modifier.width(BCSpacing.sm))
            Text(
                text = post.date,
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(text = post.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        Text(
            text = post.body,
            fontSize = 13.sp,
            maxLines = 3,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun Footer(websiteURL: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(BCSpacing.md),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = websiteURL,
            fontSize = 12.sp,
            color = BCColors.BrandBlue
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
        letterSpacing = 1.sp
    )
}
