package com.traddiff.stonebc.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.traddiff.stonebc.ui.theme.BCColors

@Composable
fun DifficultyBadge(difficulty: String) {
    val color = when (difficulty.lowercase()) {
        "easy" -> BCColors.BrandGreen
        "moderate" -> BCColors.BrandAmber
        "hard" -> Color(0xFFEA580C)
        "expert" -> BCColors.NavAlertRed
        else -> Color.Gray
    }
    Text(
        text = difficulty.replaceFirstChar { it.uppercase() },
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        color = Color.White,
        modifier = Modifier
            .background(color, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}

@Composable
fun CategoryBadge(category: String) {
    val color = when (category.lowercase()) {
        "road" -> BCColors.BrandBlue
        "gravel" -> BCColors.BrandAmber
        "fatbike" -> Color(0xFF06B6D4)
        "trail", "mountain" -> BCColors.BrandGreen
        else -> Color.Gray
    }
    Text(
        text = category.replaceFirstChar { it.uppercase() },
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        color = Color.White,
        modifier = Modifier
            .background(color, RoundedCornerShape(6.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp)
    )
}
