package com.traddiff.stonebc.data.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.traddiff.stonebc.data.database.journal.ExpeditionEntryEntity
import com.traddiff.stonebc.data.database.journal.ExpeditionJournalEntity
import com.traddiff.stonebc.data.database.journal.JournalDao

@Database(
    entities = [ExpeditionJournalEntity::class, ExpeditionEntryEntity::class],
    version = 1,
    exportSchema = false
)
abstract class StoneBCDatabase : RoomDatabase() {

    abstract fun journalDao(): JournalDao

    companion object {
        @Volatile private var instance: StoneBCDatabase? = null

        fun get(context: Context): StoneBCDatabase = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext,
                StoneBCDatabase::class.java,
                "stonebc.db"
            ).fallbackToDestructiveMigration().build().also { instance = it }
        }
    }
}
