package com.traddiff.stonebc.data.database.journal

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface JournalDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertJournal(journal: ExpeditionJournalEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertEntry(entry: ExpeditionEntryEntity)

    @Query("SELECT * FROM expedition_journals ORDER BY createdAtMillis DESC")
    fun observeJournals(): Flow<List<ExpeditionJournalEntity>>

    @Query("SELECT * FROM expedition_journals WHERE id = :id LIMIT 1")
    suspend fun getJournal(id: String): ExpeditionJournalEntity?

    @Query("SELECT * FROM expedition_entries WHERE journalId = :journalId ORDER BY timestampMillis ASC")
    fun observeEntries(journalId: String): Flow<List<ExpeditionEntryEntity>>

    @Query("SELECT * FROM expedition_entries WHERE journalId = :journalId ORDER BY timestampMillis ASC")
    suspend fun getEntries(journalId: String): List<ExpeditionEntryEntity>

    @Query("DELETE FROM expedition_journals WHERE id = :id")
    suspend fun deleteJournal(id: String)

    @Query("DELETE FROM expedition_entries WHERE id = :id")
    suspend fun deleteEntry(id: String)
}
