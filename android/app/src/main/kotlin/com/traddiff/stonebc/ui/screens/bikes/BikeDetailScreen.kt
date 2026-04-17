package com.traddiff.stonebc.ui.screens.bikes

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import com.traddiff.stonebc.data.models.Bike
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing

@Composable
fun BikeDetailScreen(bikeId: String, onBack: () -> Unit) {
    val state = LocalAppState.current
    val bike = state.bikes.firstOrNull { it.id == bikeId }
    val context = LocalContext.current

    if (bike == null) {
        Column(modifier = Modifier.fillMaxSize().padding(BCSpacing.md)) {
            BackHeader(onBack, "Bike not found")
        }
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = BCSpacing.xl)
    ) {
        BackHeader(onBack, bike.model)
        Spacer(Modifier.height(BCSpacing.sm))

        SpecsCard(bike = bike)
        Spacer(Modifier.height(BCSpacing.md))

        if (bike.features.isNotEmpty()) {
            SectionTitle("Features")
            bike.features.forEach { feature ->
                Text(
                    text = "• $feature",
                    fontSize = 14.sp,
                    modifier = Modifier.padding(horizontal = BCSpacing.md, vertical = 2.dp)
                )
            }
            Spacer(Modifier.height(BCSpacing.md))
        }

        if (bike.description.isNotBlank()) {
            SectionTitle("About")
            Text(
                text = bike.description,
                fontSize = 14.sp,
                modifier = Modifier.padding(horizontal = BCSpacing.md)
            )
            Spacer(Modifier.height(BCSpacing.md))
        }

        Button(
            onClick = {
                val email = state.config.email
                val subject = Uri.encode("Interested in ${bike.model}")
                val body = Uri.encode("Hi StoneBC, I'd like more info on bike ${bike.id}.")
                val intent = Intent(Intent.ACTION_SENDTO).apply {
                    data = Uri.parse("mailto:$email?subject=$subject&body=$body")
                }
                runCatching { context.startActivity(intent) }
            },
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = BCSpacing.md)
        ) {
            Text("Ask About This Bike", color = Color.White, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun BackHeader(onBack: () -> Unit, title: String) {
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
private fun SpecsCard(bike: Bike) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.md)
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        SpecRow("Status", bike.status)
        SpecRow("Type", bike.type)
        if (bike.frameSize.isNotBlank()) SpecRow("Frame", bike.frameSize)
        if (bike.wheelSize.isNotBlank()) SpecRow("Wheels", bike.wheelSize)
        if (bike.color.isNotBlank()) SpecRow("Color", bike.color)
        if (bike.condition.isNotBlank()) SpecRow("Condition", bike.condition)
        bike.sponsorPrice?.let { SpecRow("Sponsor price", "$$it") }
    }
}

@Composable
private fun SpecRow(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.Medium)
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
        modifier = Modifier.padding(horizontal = BCSpacing.md, vertical = BCSpacing.xs)
    )
}
