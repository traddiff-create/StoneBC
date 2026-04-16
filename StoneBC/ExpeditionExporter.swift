//
//  ExpeditionExporter.swift
//  StoneBC
//
//  Generates shareable HTML expedition report with embedded map,
//  photo gallery, and day-by-day narrative.
//

import Foundation
import UIKit

enum ExpeditionExporter {

    /// Generate a self-contained HTML expedition report
    static func exportHTML(journal: ExpeditionJournal) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(journal.name))</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0f0f0f; color: #e5e5e5; line-height: 1.6; }
                .container { max-width: 720px; margin: 0 auto; padding: 20px; }
                .hero { text-align: center; padding: 60px 20px 40px; }
                .hero h1 { font-size: 28px; font-weight: 200; letter-spacing: 4px; text-transform: uppercase; }
                .hero .subtitle { font-size: 13px; color: #888; margin-top: 8px; letter-spacing: 2px; }
                .hero .divider { width: 40px; height: 2px; background: #2563eb; margin: 16px auto; }
                .day-header { padding: 30px 0 15px; border-bottom: 1px solid #333; margin-bottom: 20px; }
                .day-header h2 { font-size: 14px; font-weight: 600; letter-spacing: 3px; text-transform: uppercase; color: #2563eb; }
                .day-header .stats { font-size: 11px; color: #888; margin-top: 4px; }
                .summary { font-size: 15px; line-height: 1.8; margin-bottom: 24px; color: #ccc; font-style: italic; border-left: 2px solid #2563eb; padding-left: 16px; }
                .entry { margin-bottom: 20px; }
                .entry .time { font-size: 10px; color: #666; font-family: monospace; letter-spacing: 1px; }
                .entry .text { font-size: 14px; margin-top: 4px; }
                .entry img { width: 100%; border-radius: 8px; margin-top: 8px; }
                .entry .audio-badge, .entry .video-badge { display: inline-block; font-size: 11px; padding: 4px 10px; border-radius: 4px; margin-top: 4px; }
                .entry .audio-badge { background: rgba(37,99,235,0.15); color: #2563eb; }
                .entry .video-badge { background: rgba(147,51,234,0.15); color: #9333ea; }
                .entry .source { font-size: 9px; color: #555; margin-left: 8px; }
                .featured { border: 1px solid #f59e0b; border-radius: 12px; padding: 12px; }
                .footer { text-align: center; padding: 40px 0; font-size: 11px; color: #555; }
                .footer a { color: #2563eb; text-decoration: none; }
                .contributors { margin: 30px 0; padding: 16px; background: #1a1a1a; border-radius: 8px; }
                .contributors h3 { font-size: 12px; letter-spacing: 2px; color: #888; margin-bottom: 8px; }
            </style>
        </head>
        <body>
        <div class="container">
            <div class="hero">
                <h1>\(escapeHTML(journal.name))</h1>
                <div class="divider"></div>
                <div class="subtitle">\(dateFormatter.string(from: journal.startDate)) &mdash; Led by \(escapeHTML(journal.leaderName))</div>
                <div class="subtitle" style="margin-top:4px">\(journal.totalPhotos) photos &middot; \(journal.totalEntries) entries &middot; \(journal.days.count) days</div>
            </div>
        """

        // Days
        for day in journal.days {
            let statsText = [
                day.actualMiles.map { String(format: "%.1f miles", $0) },
                day.actualElevation.map { "\($0) ft gained" },
                "\(day.photoCount) photos"
            ].compactMap { $0 }.joined(separator: " · ")

            html += """

                <div class="day-header">
                    <h2>Day \(day.dayNumber)</h2>
                    <div class="stats">\(statsText)</div>
                </div>
            """

            // Summary
            if let summary = day.summary, !summary.isEmpty {
                html += """

                    <div class="summary">\(escapeHTML(summary))</div>
                """
            }

            // Entries
            for entry in day.sortedEntries {
                let timeStr = {
                    let f = DateFormatter()
                    f.dateFormat = "h:mm a"
                    return f.string(from: entry.timestamp)
                }()

                let featuredClass = entry.isFeatured ? " featured" : ""

                html += """

                    <div class="entry\(featuredClass)">
                        <div class="time">\(timeStr)<span class="source">\(entry.source.label)</span></div>
                """

                // Photo (base64 inline for self-contained HTML)
                if entry.mediaType == .photo, let filename = entry.mediaFilename {
                    // Reference as relative path — user provides photos folder alongside HTML
                    html += """
                            <img src="media/day\(day.dayNumber)/\(escapeHTML(filename))" alt="\(escapeHTML(entry.text ?? "Photo"))">
                    """
                }

                // Audio/Video badges
                if entry.mediaType == .audio {
                    html += """
                            <span class="audio-badge">🎤 Voice memo</span>
                    """
                }
                if entry.mediaType == .video {
                    html += """
                            <span class="video-badge">🎬 Video clip</span>
                    """
                }

                // Text
                if let text = entry.text, !text.isEmpty {
                    html += """
                            <div class="text">\(escapeHTML(text))</div>
                    """
                }

                html += """

                    </div>
                """
            }
        }

        // Contributors
        let approvedContributions = journal.contributions.filter { $0.approved }
        if !approvedContributions.isEmpty {
            let names = Set(approvedContributions.map { $0.contributorName })
            html += """

                <div class="contributors">
                    <h3>CONTRIBUTORS</h3>
                    <div>\(names.sorted().joined(separator: " · "))</div>
                </div>
            """
        }

        // Footer
        html += """

            <div class="footer">
                Documented with <a href="https://stonebicyclecoalition.com">Stone Bicycle Coalition</a> app<br>
                &copy; \(Calendar.current.component(.year, from: Date())) \(escapeHTML(journal.leaderName))
            </div>
        </div>
        </body>
        </html>
        """

        return html
    }

    /// Save HTML export to disk
    static func saveHTML(journal: ExpeditionJournal) async -> URL? {
        let html = exportHTML(journal: journal)
        let exportDir = await ExpeditionStorage.shared.exportDir(journalId: journal.id)
        let fileURL = exportDir.appendingPathComponent("expedition.html")

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Generate plain text summary (for sharing)
    static func textSummary(journal: ExpeditionJournal) -> String {
        var text = "\(journal.name)\n"
        text += "Led by \(journal.leaderName)\n"
        text += "\(journal.days.count) days · \(journal.totalPhotos) photos · \(journal.totalEntries) entries\n\n"

        for day in journal.days {
            text += "--- Day \(day.dayNumber) ---\n"
            if let miles = day.actualMiles {
                text += "\(String(format: "%.1f", miles)) miles"
            }
            if let elev = day.actualElevation {
                text += " · \(elev) ft elevation\n"
            } else {
                text += "\n"
            }
            if let summary = day.summary {
                text += summary + "\n"
            }
            text += "\n"
        }

        text += "Documented with Stone Bicycle Coalition app\n"
        return text
    }

    // MARK: - Helpers

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
