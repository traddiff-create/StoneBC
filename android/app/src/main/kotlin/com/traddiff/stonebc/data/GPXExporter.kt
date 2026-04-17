package com.traddiff.stonebc.data

import com.traddiff.stonebc.data.models.RideSession
import com.traddiff.stonebc.data.models.Trackpoint
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object GPXExporter {

    private val iso8601 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    fun toGPX(session: RideSession, name: String = "StoneBC Ride"): String =
        buildString {
            append("""<?xml version="1.0" encoding="UTF-8"?>""")
            append('\n')
            append(
                """<gpx version="1.1" creator="StoneBC Android" xmlns="http://www.topografix.com/GPX/1/1">"""
            )
            append('\n')
            append("  <metadata><time>${iso8601.format(Date(session.startTimestamp))}</time></metadata>\n")
            append("  <trk><name>${escape(name)}</name><trkseg>\n")
            session.trackpoints.forEach { append(formatTrackpoint(it)) }
            append("  </trkseg></trk>\n")
            append("</gpx>\n")
        }

    private fun formatTrackpoint(pt: Trackpoint): String = buildString {
        append("    <trkpt lat=\"${pt.latitude}\" lon=\"${pt.longitude}\">")
        pt.elevationMeters?.let { append("<ele>${"%.2f".format(it)}</ele>") }
        append("<time>${iso8601.format(Date(pt.timestampMillis))}</time>")
        append("</trkpt>\n")
    }

    private fun escape(text: String): String =
        text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
