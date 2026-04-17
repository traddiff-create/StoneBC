package com.traddiff.stonebc

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.traddiff.stonebc.data.AppState
import com.traddiff.stonebc.data.AssetsRepository
import com.traddiff.stonebc.data.LocalAppState
import com.traddiff.stonebc.ui.navigation.MainNavHost
import com.traddiff.stonebc.ui.theme.StoneBCTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val appState = remember {
                AppState(
                    repository = AssetsRepository(applicationContext),
                    rideHistoryStore = com.traddiff.stonebc.storage.RideHistoryStore(applicationContext),
                    onboardingStore = com.traddiff.stonebc.storage.OnboardingStore(applicationContext)
                ).also { it.load() }
            }
            val onboardingComplete by appState.onboardingStore.hasCompleted
                .collectAsState(initial = null)

            StoneBCTheme {
                CompositionLocalProvider(LocalAppState provides appState) {
                    when (onboardingComplete) {
                        null -> Unit // still loading DataStore, show nothing briefly
                        false -> com.traddiff.stonebc.ui.screens.onboarding.OnboardingScreen(
                            onComplete = { /* recomposition via Flow handles it */ }
                        )
                        true -> MainNavHost()
                    }
                }
            }
        }
    }
}
