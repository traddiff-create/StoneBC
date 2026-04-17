package com.traddiff.stonebc.data.repositories

import com.traddiff.stonebc.data.models.Route

class RoutesRepository {

    fun filter(
        routes: List<Route>,
        query: String = "",
        difficulty: String? = null,
        category: String? = null
    ): List<Route> =
        routes.asSequence()
            .filter { difficulty == null || it.difficulty.equals(difficulty, ignoreCase = true) }
            .filter { category == null || it.category.equals(category, ignoreCase = true) }
            .filter { matchesQuery(it, query) }
            .sortedBy { it.name.lowercase() }
            .toList()

    private fun matchesQuery(route: Route, query: String): Boolean {
        if (query.isBlank()) return true
        val q = query.trim().lowercase()
        return route.name.lowercase().contains(q) ||
            route.description.lowercase().contains(q) ||
            route.region.lowercase().contains(q)
    }

    fun availableDifficulties(routes: List<Route>): List<String> =
        routes.map { it.difficulty }.distinct().sortedBy { difficultyRank(it) }

    fun availableCategories(routes: List<Route>): List<String> =
        routes.map { it.category }.distinct().sorted()

    private fun difficultyRank(difficulty: String): Int = when (difficulty.lowercase()) {
        "easy" -> 0; "moderate" -> 1; "hard" -> 2; "expert" -> 3; else -> 4
    }
}
