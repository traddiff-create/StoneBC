package com.traddiff.stonebc.data.database.journal

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "expedition_journals")
data class ExpeditionJournalEntity(
    @PrimaryKey val id: String,
    val name: String,
    val description: String,
    val startDateIso: String,
    val endDateIso: String,
    val leader: String,
    val createdAtMillis: Long = System.currentTimeMillis()
)

@Entity(
    tableName = "expedition_entries",
    foreignKeys = [
        ForeignKey(
            entity = ExpeditionJournalEntity::class,
            parentColumns = ["id"],
            childColumns = ["journalId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("journalId")]
)
data class ExpeditionEntryEntity(
    @PrimaryKey val id: String,
    val journalId: String,
    val dayNumber: Int,
    val timestampMillis: Long,
    val text: String,
    val mediaUri: String? = null,
    val mediaType: String = "text", // text | photo | audio | video
    val latitude: Double? = null,
    val longitude: Double? = null
)
