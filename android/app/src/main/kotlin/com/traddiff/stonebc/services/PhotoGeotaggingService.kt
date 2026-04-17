package com.traddiff.stonebc.services

import android.content.Context
import android.location.Location
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PhotoGeotaggingService {

    private val exifTimeFormat = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US)

    /**
     * Writes GPS lat/lon into the EXIF of a photo at [uri]. Best-effort —
     * returns true on success, false on any failure (including unsupported
     * content providers). The caller should still store the location in
     * Room as the authoritative record.
     */
    fun tag(context: Context, uri: Uri, location: Location): Boolean = runCatching {
        context.contentResolver.openFileDescriptor(uri, "rw")?.use { pfd ->
            val exif = ExifInterface(pfd.fileDescriptor)
            exif.setLatLong(location.latitude, location.longitude)
            exif.setAttribute(
                ExifInterface.TAG_DATETIME_ORIGINAL,
                exifTimeFormat.format(Date(location.time.takeIf { it > 0 } ?: System.currentTimeMillis()))
            )
            exif.saveAttributes()
            true
        } ?: false
    }.getOrElse { false }
}
