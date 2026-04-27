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

    /// Save a printable PDF expedition log to disk
    static func savePDF(journal: ExpeditionJournal) async -> URL? {
        let data = exportPDF(journal: journal)
        let exportDir = await ExpeditionStorage.shared.exportDir(journalId: journal.id)
        let fileURL = exportDir.appendingPathComponent("expedition-log.pdf")

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Generate a PDF expedition log with daily logistics, entries, and photo thumbnails
    static func exportPDF(journal: ExpeditionJournal) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margins = UIEdgeInsets(top: 44, left: 48, bottom: 48, right: 48)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            var y = margins.top
            context.beginPage()

            drawTitle("EXPEDITION LOG", at: &y, pageRect: pageRect, margins: margins)
            drawText(journal.name, at: &y, width: contentWidth(pageRect, margins), style: .headline)
            y += 8

            let dateText = dateRangeText(start: journal.startDate, end: journal.endDate)
            drawText(dateText, at: &y, width: contentWidth(pageRect, margins), style: .subhead)
            drawText("Leader: \(journal.leaderName)", at: &y, width: contentWidth(pageRect, margins), style: .body)
            drawText("Tracking: \((journal.trackingMode ?? .balanced).label)", at: &y, width: contentWidth(pageRect, margins), style: .body)
            y += 10

            let overview = "\(journal.days.count) days | \(journal.totalEntries) entries | \(journal.totalPhotos) photos | Offline-first field record"
            drawCallout(overview, at: &y, pageRect: pageRect, margins: margins)

            for day in journal.days {
                ensureSpace(180, y: &y, context: context, pageRect: pageRect, margins: margins)
                y += 14
                drawRule(at: &y, pageRect: pageRect, margins: margins)
                drawText("Day \(day.dayNumber)", at: &y, width: contentWidth(pageRect, margins), style: .section)

                let stats = dayStats(for: day)
                if !stats.isEmpty {
                    drawText(stats.joined(separator: " | "), at: &y, width: contentWidth(pageRect, margins), style: .caption)
                }

                let logistics = logisticsRows(for: day)
                for row in logistics {
                    ensureSpace(34, y: &y, context: context, pageRect: pageRect, margins: margins)
                    drawText(row, at: &y, width: contentWidth(pageRect, margins), style: .body)
                }

                if let summary = day.summary, !summary.isEmpty {
                    ensureSpace(60, y: &y, context: context, pageRect: pageRect, margins: margins)
                    drawText("Summary", at: &y, width: contentWidth(pageRect, margins), style: .label)
                    drawText(summary, at: &y, width: contentWidth(pageRect, margins), style: .body)
                }

                for entry in day.sortedEntries {
                    ensureSpace(86, y: &y, context: context, pageRect: pageRect, margins: margins)
                    drawEntry(entry, journal: journal, dayNumber: day.dayNumber, at: &y, pageRect: pageRect, margins: margins, context: context)
                }
            }

            ensureSpace(80, y: &y, context: context, pageRect: pageRect, margins: margins)
            y += 18
            drawRule(at: &y, pageRect: pageRect, margins: margins)
            drawText("Created with Follow My Expedition", at: &y, width: contentWidth(pageRect, margins), style: .caption)
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

private enum ExpeditionPDFTextStyle {
    case headline
    case subhead
    case section
    case label
    case body
    case caption

    var attributes: [NSAttributedString.Key: Any] {
        switch self {
        case .headline:
            [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
        case .subhead:
            [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        case .section:
            [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1)
            ]
        case .label:
            [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        case .body:
            [
                .font: UIFont.systemFont(ofSize: 11.5, weight: .regular),
                .foregroundColor: UIColor.label
            ]
        case .caption:
            [
                .font: UIFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        }
    }
}

private extension ExpeditionExporter {
    static func contentWidth(_ pageRect: CGRect, _ margins: UIEdgeInsets) -> CGFloat {
        pageRect.width - margins.left - margins.right
    }

    static func drawTitle(_ text: String, at y: inout CGFloat, pageRect: CGRect, margins: UIEdgeInsets) {
        drawText(text, at: &y, width: contentWidth(pageRect, margins), style: .caption)
        y += 4
    }

    static func drawText(_ text: String, at y: inout CGFloat, width: CGFloat, style: ExpeditionPDFTextStyle) {
        let rect = CGRect(x: 48, y: y, width: width, height: .greatestFiniteMagnitude)
        let attributed = NSAttributedString(string: text, attributes: style.attributes)
        let needed = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        attributed.draw(in: CGRect(x: rect.minX, y: rect.minY, width: width, height: needed.height))
        y += needed.height + 5
    }

    static func drawCallout(_ text: String, at y: inout CGFloat, pageRect: CGRect, margins: UIEdgeInsets) {
        let width = contentWidth(pageRect, margins)
        let attributed = NSAttributedString(string: text, attributes: ExpeditionPDFTextStyle.body.attributes)
        let needed = attributed.boundingRect(
            with: CGSize(width: width - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral
        let rect = CGRect(x: margins.left, y: y, width: width, height: needed.height + 22)

        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        attributed.draw(in: rect.insetBy(dx: 12, dy: 11))
        y += rect.height + 8
    }

    static func drawRule(at y: inout CGFloat, pageRect: CGRect, margins: UIEdgeInsets) {
        UIColor.separator.setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margins.left, y: y))
        path.addLine(to: CGPoint(x: pageRect.width - margins.right, y: y))
        path.lineWidth = 1
        path.stroke()
        y += 12
    }

    static func ensureSpace(
        _ needed: CGFloat,
        y: inout CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        margins: UIEdgeInsets
    ) {
        if y + needed > pageRect.height - margins.bottom {
            context.beginPage()
            y = margins.top
        }
    }

    static func dateRangeText(start: Date, end: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if let end {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
        return "Started \(formatter.string(from: start))"
    }

    static func dayStats(for day: JournalDay) -> [String] {
        [
            day.actualMiles.map { String(format: "%.1f mi", $0) },
            day.actualElevation.map { "\($0) ft gain" },
            "\(day.entries.count) entries",
            "\(day.photoCount) photos",
            day.audioCount > 0 ? "\(day.audioCount) audio" : nil,
            day.videoCount > 0 ? "\(day.videoCount) video" : nil
        ].compactMap { $0 }
    }

    static func logisticsRows(for day: JournalDay) -> [String] {
        [
            ("Water", day.waterNote),
            ("Food", day.foodNote),
            ("Shelter", day.shelterNote),
            ("Sunset", day.sunsetNote),
            ("Weather", day.weatherNote)
        ]
        .compactMap { label, value in
            guard let value, !value.isEmpty else { return nil }
            return "\(label): \(value)"
        }
    }

    static func drawEntry(
        _ entry: JournalEntry,
        journal: ExpeditionJournal,
        dayNumber: Int,
        at y: inout CGFloat,
        pageRect: CGRect,
        margins: UIEdgeInsets,
        context: UIGraphicsPDFRendererContext
    ) {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let parts = [
            timeFormatter.string(from: entry.timestamp),
            entry.momentKind?.label,
            entry.source.label,
            entry.coordinate.map { String(format: "%.4f, %.4f", $0[0], $0[1]) }
        ].compactMap { $0 }

        drawText(parts.joined(separator: " | "), at: &y, width: contentWidth(pageRect, margins), style: .caption)

        if let text = entry.text, !text.isEmpty {
            drawText(text, at: &y, width: contentWidth(pageRect, margins), style: .body)
        }

        if entry.mediaType == .photo,
           let filename = entry.mediaFilename,
           let image = UIImage(contentsOfFile: mediaPath(journalId: journal.id, dayNumber: dayNumber, filename: filename).path) {
            let maxHeight: CGFloat = 150
            let width = contentWidth(pageRect, margins)
            let scale = min(width / image.size.width, maxHeight / image.size.height, 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            ensureSpace(size.height + 12, y: &y, context: context, pageRect: pageRect, margins: margins)
            image.draw(in: CGRect(x: margins.left, y: y, width: size.width, height: size.height))
            y += size.height + 10
        } else if let mediaType = entry.mediaType {
            drawText("\(mediaType.rawValue.capitalized) attached", at: &y, width: contentWidth(pageRect, margins), style: .caption)
        }

        y += 5
    }

    static func mediaPath(journalId: String, dayNumber: Int, filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)/\(filename)")
    }
}
