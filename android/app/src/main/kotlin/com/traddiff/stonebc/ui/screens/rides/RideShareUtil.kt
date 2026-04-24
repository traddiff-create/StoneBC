package com.traddiff.stonebc.ui.screens.rides

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface
import androidx.core.content.FileProvider
import com.traddiff.stonebc.storage.RideEntry
import java.io.File

object RideShareUtil {

    private const val W = 1200
    private const val H = 628
    private val BRAND_BLUE = Color.parseColor("#2563EB")
    private val GREEN_DOT = Color.parseColor("#22C55E")
    private val RED_DOT = Color.parseColor("#EF4444")

    fun share(context: Context, entry: RideEntry) {
        val bitmap = render(entry)
        val file = File(context.cacheDir, "stonebc_share.png")
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()

        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        val sendIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "${entry.routeName} — %.2f mi  #StoneBC".format(entry.distanceMiles))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(sendIntent, "Share Ride").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(chooser)
    }

    private fun render(entry: RideEntry): Bitmap {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawBackground(canvas)
        val trackpoints = entry.gpxTrackpoints ?: emptyList()
        if (trackpoints.size >= 2) drawRoute(canvas, trackpoints)
        drawOverlay(canvas, entry)
        drawWatermark(canvas)
        return bmp
    }

    private fun drawBackground(canvas: Canvas) {
        val paint = Paint().apply {
            shader = LinearGradient(
                0f, 0f, W.toFloat(), H.toFloat(),
                intArrayOf(Color.parseColor("#0F172A"), Color.parseColor("#1E3A5F")),
                null,
                Shader.TileMode.CLAMP
            )
        }
        canvas.drawRect(0f, 0f, W.toFloat(), H.toFloat(), paint)
    }

    private fun drawRoute(canvas: Canvas, trackpoints: List<List<Double>>) {
        val lats = trackpoints.mapNotNull { it.getOrNull(0) }
        val lons = trackpoints.mapNotNull { it.getOrNull(1) }
        val minLat = lats.min(); val maxLat = lats.max()
        val minLon = lons.min(); val maxLon = lons.max()
        val latRange = (maxLat - minLat).coerceAtLeast(0.001)
        val lonRange = (maxLon - minLon).coerceAtLeast(0.001)

        val pad = W * 0.08f
        val drawW = W - 2 * pad
        val drawH = H * 0.70f - 2 * pad

        fun toX(lon: Double) = (pad + (lon - minLon) / lonRange * drawW).toFloat()
        fun toY(lat: Double) = (pad + (maxLat - lat) / latRange * drawH).toFloat()

        val path = Path()
        trackpoints.forEachIndexed { i, pt ->
            val lat = pt.getOrNull(0) ?: return@forEachIndexed
            val lon = pt.getOrNull(1) ?: return@forEachIndexed
            if (i == 0) path.moveTo(toX(lon), toY(lat)) else path.lineTo(toX(lon), toY(lat))
        }

        canvas.drawPath(path, Paint().apply {
            color = BRAND_BLUE
            style = Paint.Style.STROKE
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            isAntiAlias = true
        })

        val first = trackpoints.first()
        canvas.drawCircle(toX(first[1]), toY(first[0]), 14f, Paint().apply {
            color = GREEN_DOT; isAntiAlias = true
        })
        val last = trackpoints.last()
        canvas.drawCircle(toX(last[1]), toY(last[0]), 14f, Paint().apply {
            color = RED_DOT; isAntiAlias = true
        })
    }

    private fun drawOverlay(canvas: Canvas, entry: RideEntry) {
        val overlayTop = H * 0.68f
        canvas.drawRect(0f, overlayTop, W.toFloat(), H.toFloat(), Paint().apply {
            color = Color.argb(210, 10, 20, 40)
        })

        val left = 40f
        canvas.drawText(
            entry.routeName.take(40),
            left, overlayTop + 54f,
            Paint().apply {
                color = Color.WHITE
                textSize = 50f
                typeface = Typeface.DEFAULT_BOLD
                isAntiAlias = true
            }
        )
        canvas.drawText(
            entry.date,
            left, overlayTop + 94f,
            Paint().apply {
                color = Color.parseColor("#94A3B8")
                textSize = 28f
                isAntiAlias = true
            }
        )
        val stats = "%.2f mi   %s   %,d ft gain".format(
            entry.distanceMiles,
            formatDuration(entry.durationSeconds),
            entry.elevationGainFeet
        )
        canvas.drawText(stats, left, overlayTop + 148f, Paint().apply {
            color = Color.WHITE
            textSize = 34f
            typeface = Typeface.DEFAULT_BOLD
            isAntiAlias = true
        })
    }

    private fun drawWatermark(canvas: Canvas) {
        canvas.drawText(
            "Stone Bicycle Coalition",
            W - 370f, 46f,
            Paint().apply {
                color = Color.parseColor("#64748B")
                textSize = 26f
                isAntiAlias = true
            }
        )
    }

    private fun formatDuration(seconds: Long): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
    }
}
