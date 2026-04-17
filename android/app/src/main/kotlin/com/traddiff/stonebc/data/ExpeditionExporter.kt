package com.traddiff.stonebc.data

import com.traddiff.stonebc.data.database.journal.ExpeditionEntryEntity
import com.traddiff.stonebc.data.database.journal.ExpeditionJournalEntity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object ExpeditionExporter {

    private val dateFormat = SimpleDateFormat("MMM d, yyyy 'at' h:mm a", Locale.US)

    fun toHtml(journal: ExpeditionJournalEntity, entries: List<ExpeditionEntryEntity>): String =
        buildString {
            append("<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"UTF-8\">")
            append("<title>${escape(journal.name)}</title>")
            append("<style>")
            append("body{background:#0b0b0b;color:#fafafa;font-family:-apple-system,Roboto,sans-serif;margin:0;padding:32px;}")
            append("h1{font-weight:300;font-size:28px;border-bottom:1px solid #333;padding-bottom:12px;}")
            append("h2{color:#2563eb;font-size:16px;letter-spacing:1px;text-transform:uppercase;}")
            append(".entry{background:#151515;border-radius:10px;padding:16px;margin:12px 0;}")
            append(".ts{color:#888;font-size:12px;margin-bottom:6px;}")
            append(".gps{color:#059669;font-size:11px;font-family:monospace;}")
            append("</style></head><body>")
            append("<h1>${escape(journal.name)}</h1>")
            append("<p><strong>Leader:</strong> ${escape(journal.leader)} · ")
            append("<strong>Dates:</strong> ${escape(journal.startDateIso)} → ${escape(journal.endDateIso)}</p>")
            if (journal.description.isNotBlank()) {
                append("<p>${escape(journal.description)}</p>")
            }

            entries.groupBy { it.dayNumber }.toSortedMap().forEach { (day, dayEntries) ->
                append("<h2>Day $day</h2>")
                dayEntries.forEach { entry ->
                    append("<div class=\"entry\">")
                    append("<div class=\"ts\">${escape(dateFormat.format(Date(entry.timestampMillis)))}</div>")
                    append("<div>${escape(entry.text).replace("\n", "<br>")}</div>")
                    if (entry.latitude != null && entry.longitude != null) {
                        append("<div class=\"gps\">${"%.5f".format(entry.latitude)}, ${"%.5f".format(entry.longitude)}</div>")
                    }
                    append("</div>")
                }
            }
            append("</body></html>\n")
        }

    private fun escape(text: String): String =
        text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
}
