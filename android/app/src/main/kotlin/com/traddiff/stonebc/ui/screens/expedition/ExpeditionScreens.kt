package com.traddiff.stonebc.ui.screens.expedition

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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.traddiff.stonebc.data.ExpeditionExporter
import com.traddiff.stonebc.data.database.StoneBCDatabase
import com.traddiff.stonebc.data.database.journal.ExpeditionEntryEntity
import com.traddiff.stonebc.data.database.journal.ExpeditionJournalEntity
import com.traddiff.stonebc.ui.theme.BCColors
import com.traddiff.stonebc.ui.theme.BCSpacing
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

@Composable
fun ExpeditionListScreen(onBack: () -> Unit, onOpen: (String) -> Unit, onNew: () -> Unit) {
    val context = LocalContext.current
    val dao = remember { StoneBCDatabase.get(context).journalDao() }
    val journals by dao.observeJournals().collectAsState(initial = emptyList())

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = onNew, containerColor = BCColors.BrandBlue) {
                Icon(Icons.Default.Add, contentDescription = "New", tint = Color.White)
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            BackHeader(onBack, "Expedition Journal")
            if (journals.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(BCSpacing.lg),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Tap + to start your first expedition journal.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
                ) {
                    items(journals, key = { it.id }) { journal ->
                        JournalRow(journal = journal, onTap = { onOpen(journal.id) })
                    }
                }
            }
        }
    }
}

@Composable
private fun JournalRow(journal: ExpeditionJournalEntity, onTap: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                RoundedCornerShape(12.dp)
            )
            .clickable(onClick = onTap)
            .padding(BCSpacing.md),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(journal.name, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        Text(
            "${journal.startDateIso} → ${journal.endDateIso}",
            fontSize = 12.sp,
            color = BCColors.BrandBlue
        )
        Text("Leader: ${journal.leader}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (journal.description.isNotBlank()) {
            Text(journal.description, fontSize = 12.sp, maxLines = 2)
        }
    }
}

@Composable
fun ExpeditionNewScreen(onBack: () -> Unit, onCreated: (String) -> Unit) {
    val context = LocalContext.current
    val dao = remember { StoneBCDatabase.get(context).journalDao() }
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var leader by remember { mutableStateOf("") }
    var startDate by remember { mutableStateOf(todayIso()) }
    var endDate by remember { mutableStateOf(todayIso()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        BackHeader(onBack, "New Expedition")
        Column(
            modifier = Modifier.padding(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Expedition name") },
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = leader,
                onValueChange = { leader = it },
                label = { Text("Trip leader") },
                modifier = Modifier.fillMaxWidth()
            )
            Row(horizontalArrangement = Arrangement.spacedBy(BCSpacing.sm)) {
                OutlinedTextField(
                    value = startDate,
                    onValueChange = { startDate = it },
                    label = { Text("Start (YYYY-MM-DD)") },
                    modifier = Modifier.weight(1f)
                )
                OutlinedTextField(
                    value = endDate,
                    onValueChange = { endDate = it },
                    label = { Text("End") },
                    modifier = Modifier.weight(1f)
                )
            }
            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                label = { Text("Description (optional)") },
                modifier = Modifier.fillMaxWidth().height(120.dp),
                keyboardOptions = KeyboardOptions.Default
            )
            Button(
                onClick = {
                    if (name.isBlank() || leader.isBlank()) return@Button
                    val id = UUID.randomUUID().toString()
                    scope.launch {
                        dao.upsertJournal(
                            ExpeditionJournalEntity(
                                id = id,
                                name = name.trim(),
                                description = description.trim(),
                                startDateIso = startDate.trim(),
                                endDateIso = endDate.trim(),
                                leader = leader.trim()
                            )
                        )
                        onCreated(id)
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Create Journal", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
fun ExpeditionDetailScreen(
    journalId: String,
    onBack: () -> Unit,
    onAddEntry: (String) -> Unit
) {
    val context = LocalContext.current
    val dao = remember { StoneBCDatabase.get(context).journalDao() }
    val scope = rememberCoroutineScope()

    var journal by remember { mutableStateOf<ExpeditionJournalEntity?>(null) }
    val entries by dao.observeEntries(journalId).collectAsState(initial = emptyList())

    LaunchedEffect(journalId) { journal = dao.getJournal(journalId) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { onAddEntry(journalId) },
                containerColor = BCColors.BrandBlue
            ) {
                Icon(Icons.Default.Add, contentDescription = "Add entry", tint = Color.White)
            }
        }
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            BackHeader(onBack, journal?.name ?: "Expedition")
            journal?.let { j ->
                ExportButton(
                    onClick = {
                        scope.launch {
                            val html = ExpeditionExporter.toHtml(j, dao.getEntries(j.id))
                            exportAndShare(context, j.name, html)
                        }
                    }
                )
            }
            if (entries.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize().padding(BCSpacing.lg),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Tap + to log your first entry. Text, photos, and GPS tags welcome.",
                        fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(BCSpacing.md),
                    verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
                ) {
                    items(entries, key = { it.id }) { entry ->
                        EntryRow(entry = entry)
                    }
                }
            }
        }
    }
}

@Composable
private fun ExportButton(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BCSpacing.md, vertical = BCSpacing.xs),
        horizontalArrangement = Arrangement.End
    ) {
        Button(
            onClick = onClick,
            colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandGreen)
        ) {
            Icon(Icons.Default.IosShare, contentDescription = null, tint = Color.White)
            Spacer(Modifier.padding(horizontal = 4.dp))
            Text("Export HTML", color = Color.White, fontSize = 13.sp)
        }
    }
}

@Composable
private fun EntryRow(entry: ExpeditionEntryEntity) {
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
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                "DAY ${entry.dayNumber}",
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = BCColors.BrandBlue,
                modifier = Modifier
                    .background(BCColors.BrandBlue.copy(alpha = 0.15f), RoundedCornerShape(4.dp))
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )
            Text(
                formatTime(entry.timestampMillis),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(entry.text, fontSize = 14.sp)
        if (entry.latitude != null && entry.longitude != null) {
            Text(
                "📍 ${"%.5f".format(entry.latitude)}, ${"%.5f".format(entry.longitude)}",
                fontSize = 11.sp,
                color = BCColors.BrandGreen,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
fun ExpeditionCaptureScreen(journalId: String, onBack: () -> Unit) {
    val context = LocalContext.current
    val dao = remember { StoneBCDatabase.get(context).journalDao() }
    val scope = rememberCoroutineScope()

    var dayText by remember { mutableStateOf("1") }
    var body by remember { mutableStateOf("") }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())
    ) {
        BackHeader(onBack, "New Entry")
        Column(
            modifier = Modifier.padding(BCSpacing.md),
            verticalArrangement = Arrangement.spacedBy(BCSpacing.sm)
        ) {
            OutlinedTextField(
                value = dayText,
                onValueChange = { dayText = it.filter { ch -> ch.isDigit() } },
                label = { Text("Day number") },
                modifier = Modifier.fillMaxWidth()
            )
            OutlinedTextField(
                value = body,
                onValueChange = { body = it },
                label = { Text("What happened?") },
                modifier = Modifier.fillMaxWidth().height(220.dp)
            )
            Button(
                onClick = {
                    if (body.isBlank()) return@Button
                    scope.launch {
                        dao.upsertEntry(
                            ExpeditionEntryEntity(
                                id = UUID.randomUUID().toString(),
                                journalId = journalId,
                                dayNumber = dayText.toIntOrNull() ?: 1,
                                timestampMillis = System.currentTimeMillis(),
                                text = body.trim(),
                                mediaType = "text"
                            )
                        )
                        onBack()
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = BCColors.BrandBlue),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Save Entry", color = Color.White, fontWeight = FontWeight.SemiBold)
            }
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

private fun todayIso(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
private fun formatTime(ms: Long): String = SimpleDateFormat("h:mm a", Locale.US).format(Date(ms))

private fun exportAndShare(context: android.content.Context, name: String, html: String) {
    runCatching {
        val safeName = name.replace(Regex("[^A-Za-z0-9]+"), "-").lowercase()
        val file = File(context.cacheDir, "expedition-$safeName.html")
        file.writeText(html)
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/html"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Expedition: $name")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Share expedition"))
    }.onFailure { android.util.Log.e("ExpeditionExport", "Share failed", it) }
}
