package com.traddiff.stonebc

import com.traddiff.stonebc.shared.models.AppConfig
import com.traddiff.stonebc.shared.models.BikesFile
import com.traddiff.stonebc.shared.models.Event
import com.traddiff.stonebc.shared.models.Photo
import com.traddiff.stonebc.shared.models.Post
import com.traddiff.stonebc.shared.models.Program
import com.traddiff.stonebc.shared.models.Route
import com.traddiff.stonebc.shared.models.TourGuide
import java.io.File
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AssetParityTest {
    private val repoRoot = findRepoRoot()
    private val androidAssets = File(repoRoot, "android/app/src/main/assets")
    private val iosAssets = File(repoRoot, "StoneBC")
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    @Test
    fun androidAssetsMatchCanonicalBundleJson() {
        val names = listOf(
            "config.json",
            "bikes.json",
            "posts.json",
            "events.json",
            "programs.json",
            "routes.json",
            "guides.json",
            "photos.json"
        )

        names.forEach { name ->
            assertArrayEquals(
                "$name drifted from StoneBC bundle source",
                File(iosAssets, name).readBytes(),
                File(androidAssets, name).readBytes()
            )
        }
    }

    @Test
    fun bundledJsonDecodesThroughSharedContracts() {
        val config = decode<AppConfig>("config.json")
        val bikes = decode<BikesFile>("bikes.json").bikes
        val posts = decodeList("posts.json", Post.serializer())
        val events = decodeList("events.json", Event.serializer())
        val programs = decodeList("programs.json", Program.serializer())
        val routes = decodeList("routes.json", Route.serializer())
        val guides = decodeList("guides.json", TourGuide.serializer())
        val photos = decodeList("photos.json", Photo.serializer())

        assertEquals("Stone Bicycle Coalition", config.coalitionName)
        assertEquals(0, bikes.size)
        assertTrue(posts.isNotEmpty())
        assertTrue(events.isNotEmpty())
        assertTrue(programs.isNotEmpty())
        assertTrue(routes.size >= 50)
        assertTrue(guides.isNotEmpty())
        assertTrue(photos.isNotEmpty())
    }

    private inline fun <reified T> decode(name: String): T =
        json.decodeFromString(File(androidAssets, name).readText())

    private fun <T> decodeList(
        name: String,
        serializer: kotlinx.serialization.KSerializer<T>
    ): List<T> =
        json.decodeFromString(ListSerializer(serializer), File(androidAssets, name).readText())

    private fun findRepoRoot(): File {
        val userDir = System.getProperty("user.dir") ?: error("Missing user.dir")
        var dir = File(userDir).canonicalFile
        repeat(6) {
            if (File(dir, "StoneBC/config.json").exists()) return dir
            dir = dir.parentFile ?: error("Could not walk past filesystem root from $userDir")
        }
        error("Could not locate StoneBC repo root from $userDir")
    }
}
