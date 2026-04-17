package com.traddiff.stonebc.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Mirrors `BCColors` from the iOS `BCDesignSystem.swift`. Single source of
 * truth for brand tokens; feed these into `StoneBCTheme`'s ColorScheme.
 */
object BCColors {
    val BrandBlue = Color(0xFF2563EB)
    val BrandGreen = Color(0xFF059669)
    val BrandAmber = Color(0xFFF59E0B)

    // Immersive ride navigation
    val NavPanel = Color(0xFF0A0A0A)
    val NavTileHighlight = Color(0x14FFFFFF)      // white @ 8 %
    val NavAlertAmber = Color(0xFFD97706)
    val NavAlertRed = Color(0xFFDC2626)
}
