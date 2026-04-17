package com.traddiff.stonebc.ui.screens.onboarding

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsBike
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Backpack
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Construction
import androidx.compose.material.icons.filled.FiberManualRecord
import androidx.compose.material.icons.filled.Hearing
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material.icons.filled.Rocket
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.storage.OnboardingStore
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing
import kotlinx.coroutines.launch

data class OnboardingCard(
    val icon: ImageVector,
    val iconTint: Color,
    val title: String,
    val subtitle: String,
    val action: CardAction = CardAction.Next
)

sealed class CardAction {
    data object Next : CardAction()
    data class Permission(val permissions: Array<String>, val label: String) : CardAction()
    data object Finish : CardAction()
}

private val cards = listOf(
    OnboardingCard(
        icon = Icons.AutoMirrored.Filled.DirectionsBike,
        iconTint = BCColors.BrandBlue,
        title = "Welcome to StoneBC",
        subtitle = "Black Hills cycling, community, and co-op bikes in one app."
    ),
    OnboardingCard(
        icon = Icons.Default.Map,
        iconTint = BCColors.BrandBlue,
        title = "56 Offline Routes",
        subtitle = "Curated Black Hills rides with elevation profiles and offline-ready maps."
    ),
    OnboardingCard(
        icon = Icons.AutoMirrored.Filled.DirectionsWalk,
        iconTint = BCColors.BrandGreen,
        title = "Glance-First Navigation",
        subtitle = "Huge speed hero, mini elevation, and off-route alerts tuned for gloved hands."
    ),
    OnboardingCard(
        icon = Icons.Default.FiberManualRecord,
        iconTint = BCColors.NavAlertRed,
        title = "Record Every Ride",
        subtitle = "GPS tracking with 7-second auto-pause and GPX export when you're done."
    ),
    OnboardingCard(
        icon = Icons.Default.PhoneIphone,
        iconTint = Color.Gray,
        title = "Rally Radio — iOS Only",
        subtitle = "Peer-to-peer voice chat is iOS-exclusive (MultipeerConnectivity). Skipping on Android."
    ),
    OnboardingCard(
        icon = Icons.Default.Construction,
        iconTint = BCColors.BrandAmber,
        title = "Swiss Army Knife",
        subtitle = "Weather, trail conditions, USFS closures, Strava sync, emergency tools, offline cache."
    ),
    OnboardingCard(
        icon = Icons.Default.Book,
        iconTint = BCColors.BrandBlue,
        title = "Expedition Journal",
        subtitle = "Lewis & Clark–style docs for multi-day trips — text, photos, GPS, HTML export."
    ),
    OnboardingCard(
        icon = Icons.Default.LocationOn,
        iconTint = BCColors.BrandGreen,
        title = "Location Access",
        subtitle = "Needed to record rides, show your position on route maps, and detect off-route drift.",
        action = CardAction.Permission(
            permissions = arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ),
            label = "Allow Location"
        )
    ),
    OnboardingCard(
        icon = Icons.Default.MonitorHeart,
        iconTint = BCColors.BrandAmber,
        title = "Activity Sensors",
        subtitle = "We use step detection for smart auto-pause and auto-resume while you ride.",
        action = CardAction.Permission(
            permissions = arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            label = "Allow Activity"
        )
    ),
    OnboardingCard(
        icon = Icons.Default.Hearing,
        iconTint = BCColors.NavAlertAmber,
        title = "Audio Cues",
        subtitle = "Off-route alerts and spoken distance to next turn. Works with your helmet speaker."
    ),
    OnboardingCard(
        icon = Icons.Default.Notifications,
        iconTint = BCColors.BrandBlue,
        title = "Notifications",
        subtitle = "Ride event reminders, trail condition alerts, and ongoing ride notification.",
        action = CardAction.Permission(
            permissions = arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            label = "Allow Notifications"
        )
    ),
    OnboardingCard(
        icon = Icons.Default.Rocket,
        iconTint = BCColors.BrandGreen,
        title = "Ready to Ride",
        subtitle = "Start exploring the Routes tab, or tap Record to log your first StoneBC ride.",
        action = CardAction.Finish
    )
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(onComplete: () -> Unit) {
    val context = LocalContext.current
    val store = remember { OnboardingStore(context) }
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(pageCount = { cards.size })

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* Result ignored — user can grant later from system settings */ }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
        ) { index ->
            CardContent(card = cards[index])
        }

        ProgressDots(currentPage = pagerState.currentPage, totalPages = cards.size)
        Spacer(Modifier.height(BCSpacing.md))

        val currentCard = cards[pagerState.currentPage]
        NavControls(
            card = currentCard,
            onNext = {
                scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
            },
            onBack = {
                scope.launch { pagerState.animateScrollToPage(pagerState.currentPage - 1) }
            },
            onPermission = { perms ->
                permissionLauncher.launch(perms)
                scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
            },
            onFinish = {
                scope.launch {
                    store.markComplete()
                    onComplete()
                }
            },
            canGoBack = pagerState.currentPage > 0,
            isLastPage = pagerState.currentPage == cards.size - 1
        )
        Spacer(Modifier.height(BCSpacing.lg))
    }
}

@Composable
private fun CardContent(card: OnboardingCard) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(BCSpacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(120.dp)
                .background(card.iconTint.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = card.icon,
                contentDescription = null,
                tint = card.iconTint,
                modifier = Modifier.size(64.dp)
            )
        }
        Spacer(Modifier.height(BCSpacing.xl))
        Text(
            text = card.title,
            fontSize = 28.sp,
            fontWeight = FontWeight.Light,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(BCSpacing.md))
        Text(
            text = card.subtitle,
            fontSize = 15.sp,
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = BCSpacing.md)
        )
    }
}

@Composable
private fun ProgressDots(currentPage: Int, totalPages: Int) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = BCSpacing.sm),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Spacer(Modifier.weight(1f))
        repeat(totalPages) { index ->
            val size = if (index == currentPage) 10.dp else 6.dp
            val color = if (index == currentPage) BCColors.BrandBlue else Color.Gray.copy(alpha = 0.4f)
            Box(
                modifier = Modifier
                    .size(size)
                    .background(color, CircleShape)
            )
        }
        Spacer(Modifier.weight(1f))
    }
}

@Composable
private fun NavControls(
    card: OnboardingCard,
    onNext: () -> Unit,
    onBack: () -> Unit,
    onPermission: (Array<String>) -> Unit,
    onFinish: () -> Unit,
    canGoBack: Boolean,
    isLastPage: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.md),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (canGoBack) {
            TextButton(onClick = onBack) { Text("Back") }
        } else {
            Spacer(Modifier.size(1.dp))
        }

        when (val action = card.action) {
            is CardAction.Next -> Button(
                onClick = onNext,
                colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue)
            ) {
                Text("Next", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
            is CardAction.Permission -> Button(
                onClick = { onPermission(action.permissions) },
                colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandGreen)
            ) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color.White)
                Spacer(Modifier.size(6.dp))
                Text(action.label, color = Color.White, fontWeight = FontWeight.SemiBold)
            }
            CardAction.Finish -> Button(
                onClick = onFinish,
                colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandGreen)
            ) {
                Text("Get Started", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}
