package com.traddiff.stonebc

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
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
                AppState(AssetsRepository(applicationContext)).also { it.load() }
            }
            StoneBCTheme {
                CompositionLocalProvider(LocalAppState provides appState) {
                    MainNavHost()
                }
            }
        }
    }
}
