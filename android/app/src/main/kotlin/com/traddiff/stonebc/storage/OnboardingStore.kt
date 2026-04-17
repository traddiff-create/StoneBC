package com.traddiff.stonebc.storage

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.onboardingDataStore by preferencesDataStore(name = "onboarding")

class OnboardingStore(private val context: Context) {

    private val completedKey = booleanPreferencesKey("completed")

    val hasCompleted: Flow<Boolean> =
        context.onboardingDataStore.data.map { it[completedKey] ?: false }

    suspend fun markComplete() {
        context.onboardingDataStore.edit { it[completedKey] = true }
    }

    suspend fun reset() {
        context.onboardingDataStore.edit { it[completedKey] = false }
    }
}
