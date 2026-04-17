package com.traddiff.stonebc.ui.screens.more

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun BackHeader(onBack: () -> Unit, title: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = BCSpacing.sm, vertical = BCSpacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = "Back",
            modifier = Modifier.clickable(onClick = onBack).padding(BCSpacing.xs)
        )
        Spacer(Modifier.padding(horizontal = 4.dp))
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun CommunityFeedScreen(onBack: () -> Unit) {
    val posts = LocalAppState.current.posts.sortedByDescending { it.date }
    Column(Modifier.fillMaxSize()) {
        BackHeader(onBack, "Community Feed")
        LazyColumn(
            contentPadding = PaddingValues(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            items(posts, key = { it.id }) { post ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                        .padding(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            post.category.uppercase(),
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Medium,
                            color = BCColors.BrandBlue,
                            modifier = Modifier
                                .background(BCColors.BrandBlue.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                        Text(post.date, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(post.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Text(post.body, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
fun EventsScreen(onBack: () -> Unit) {
    val events = LocalAppState.current.events
    Column(Modifier.fillMaxSize()) {
        BackHeader(onBack, "Events")
        LazyColumn(
            contentPadding = PaddingValues(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            items(events, key = { it.id }) { event ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                        .padding(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(event.title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(event.date, fontSize = 12.sp, color = BCColors.BrandBlue)
                        if (event.location.isNotBlank()) {
                            Text("· ${event.location}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    if (event.description.isNotBlank()) {
                        Text(event.description, fontSize = 13.sp)
                    }
                }
            }
        }
    }
}

@Composable
fun ProgramsScreen(onBack: () -> Unit) {
    val programs = LocalAppState.current.programs
    Column(Modifier.fillMaxSize()) {
        BackHeader(onBack, "Programs")
        LazyColumn(
            contentPadding = PaddingValues(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            items(programs, key = { it.id }) { program ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                        .padding(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(program.name, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    Text(program.description, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    program.details.forEach { detail ->
                        Text("• $detail", fontSize = 12.sp, modifier = Modifier.padding(start = 4.dp))
                    }
                    if (program.schedule.isNotBlank()) {
                        Text("Schedule: ${program.schedule}", fontSize = 12.sp, color = BCColors.BrandBlue)
                    }
                }
            }
        }
    }
}

@Composable
fun GalleryScreen(onBack: () -> Unit) {
    val photos = LocalAppState.current.photos
    Column(Modifier.fillMaxSize()) {
        BackHeader(onBack, "Gallery")
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            contentPadding = PaddingValues(BCSpacing.xs),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.xs),
            horizontalArrangement = Arrangement.spacedBy(BCSpacing.xs)
        ) {
            items(photos, key = { it.id }) { photo ->
                Box(
                    modifier = Modifier
                        .aspectRatio(1f)
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(6.dp)
                        ),
                    contentAlignment = Alignment.BottomStart
                ) {
                    Text(
                        photo.title,
                        fontSize = 9.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(4.dp),
                        maxLines = 2
                    )
                }
            }
        }
    }
}

@Composable
fun TourGuidesScreen(onBack: () -> Unit) {
    val guides = LocalAppState.current.tourGuides
    Column(Modifier.fillMaxSize()) {
        BackHeader(onBack, "Tour Guides")
        LazyColumn(
            contentPadding = PaddingValues(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            items(guides, key = { it.id }) { guide ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                            RoundedCornerShape(12.dp)
                        )
                        .padding(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(guide.name, fontSize = 18.sp, fontWeight = FontWeight.SemiBold)
                    if (guide.subtitle.isNotBlank()) {
                        Text(guide.subtitle, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text("${guide.totalDays} days", fontSize = 13.sp, color = BCColors.BrandBlue)
                        Text("${"%.1f".format(guide.totalMiles)} mi", fontSize = 13.sp, color = BCColors.BrandBlue)
                        Text("${guide.totalElevation} ft", fontSize = 13.sp, color = BCColors.BrandBlue)
                    }
                    if (guide.eventDate.isNotBlank()) {
                        Text(guide.eventDate, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(guide.description, fontSize = 12.sp, maxLines = 3)
                    guide.days.forEachIndexed { index, day ->
                        Spacer(Modifier.height(4.dp))
                        Text(
                            "Day ${day.dayNumber}: ${day.name}",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            "${day.date} · ${"%.1f".format(day.totalMiles)} mi · ${day.stops.size} stops",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun VolunteerScreen(onBack: () -> Unit) {
    MailtoForm(
        onBack = onBack,
        title = "Volunteer",
        subject = "Volunteer interest — TTT",
        body = "Hi Stone Bicycle Coalition,\n\nI'd like to volunteer. My interests:\n- Time: \n- Talent: \n- Treasure: \n\nMore details:\n",
        cta = "Open Email",
        description = "Tell us how you'd like to help — Time (volunteer hours), Talent (skills you'll share), or Treasure (financial support)."
    )
}

@Composable
fun DonateScreen(onBack: () -> Unit) {
    MailtoForm(
        onBack = onBack,
        title = "Donate",
        subject = "Donation — Bikes / Parts / Funds",
        body = "Hi Stone Bicycle Coalition,\n\nI'd like to donate:\n- Type (bicycle, parts, monetary): \n- Condition: \n- Description: \n- Pickup / drop-off preference: \n\nMore details:\n",
        cta = "Open Email",
        description = "We accept bicycles, parts, and monetary donations. Share a few details and we'll follow up."
    )
}

@Composable
private fun MailtoForm(
    onBack: () -> Unit,
    title: String,
    subject: String,
    body: String,
    cta: String,
    description: String
) {
    val context = LocalContext.current
    val email = LocalAppState.current.config.email
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        BackHeader(onBack, title)
        Text(
            description,
            fontSize = 13.sp,
            modifier = Modifier.padding(BCSpacing.md)
        )
        Button(
            onClick = {
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("mailto:$email?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}")
                }
                runCatching { context.startActivity(intent) }
            },
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = BCSpacing.md)
        ) {
            Text(cta, color = Color.White, fontWeight = FontWeight.SemiBold)
        }
    }
}
