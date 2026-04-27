package com.traddiff.stonebc

import com.traddiff.stonebc.shared.models.RideSession
import com.traddiff.stonebc.shared.models.RouteRecordingMode
import com.traddiff.stonebc.shared.models.Trackpoint
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RideSessionContractTest {
    @Test
    fun routeRecordingMetadataTravelsWithSession() {
        val session = RideSession(
            id = "ride-1",
            startTimestamp = 1_000L,
            recordingMode = RouteRecordingMode.follow,
            routeId = "8-over-7",
            routeName = "8 Over 7",
            routeCategory = "gravel",
            trackpoints = listOf(
                Trackpoint(44.0, -103.0, 1_000.0, 4f, 1_000L),
                Trackpoint(44.001, -103.001, 1_010.0, 5f, 61_000L)
            )
        )

        assertEquals(RouteRecordingMode.follow, session.recordingMode)
        assertEquals("8-over-7", session.routeId)
        assertEquals("8 Over 7", session.routeName)
        assertEquals("gravel", session.routeCategory)
        assertTrue(session.distanceMiles > 0.0)
        assertEquals(10, session.elevationGainMeters.toInt())
        assertEquals(60, session.durationSeconds)
    }
}
