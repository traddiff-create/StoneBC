package com.traddiff.stonebc.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = BCColors.BrandBlue,
    secondary = BCColors.BrandGreen,
    tertiary = BCColors.BrandAmber
)

private val DarkColors = darkColorScheme(
    primary = BCColors.BrandBlue,
    secondary = BCColors.BrandGreen,
    tertiary = BCColors.BrandAmber
)

@Composable
fun StoneBCTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content
    )
}
