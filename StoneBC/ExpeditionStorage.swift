//
//  ExpeditionStorage.swift
//  StoneBC
//
//  Persistent storage for expedition journals — Documents directory for local,
//  iCloud Drive 8o7/ folder for shared media drops from other riders.
//

import Foundation
import UIKit

actor ExpeditionStorage {
    static let shared = ExpeditionStorage()

    private let baseDir: URL

    /// iCloud Drive shared drop zone for contributions.
    /// On iOS, uses the ubiquity container. On macOS, uses direct path.
    private let iCloudDropZone: URL?

    init(documentsDirectory: URL? = nil) {
        let docs = documentsDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let base = docs.appendingPathComponent("Expeditions", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.baseDir = base

        if documentsDirectory != nil {
            // Test override: route the drop zone under the same temp tree.
            let zone = docs.appendingPathComponent("8o7", isDirectory: true)
            try? FileManager.default.createDirectory(at: zone, withIntermediateDirectories: true)
            self.iCloudDropZone = zone
        } else if let ubiquity = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let zone = ubiquity.appendingPathComponent("Documents/8o7", isDirectory: true)
            try? FileManager.default.createDirectory(at: zone, withIntermediateDirectories: true)
            self.iCloudDropZone = zone
        } else {
            let zone = docs.appendingPathComponent("8o7", isDirectory: true)
            try? FileManager.default.createDirectory(at: zone, withIntermediateDirectories: true)
            self.iCloudDropZone = zone
        }
    }

    // MARK: - Journal CRUD

    func save(_ journal: ExpeditionJournal) {
        let dir = journalDir(for: journal.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        if let data = try? encoder.encode(journal) {
            try? data.write(to: dir.appendingPathComponent("journal.json"))
        }
    }

    func load(id: String) -> ExpeditionJournal? {
        let file = journalDir(for: id).appendingPathComponent("journal.json")
        guard let data = try? Data(contentsOf: file) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ExpeditionJournal.self, from: data)
    }

    func listJournals() -> [ExpeditionJournal] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: baseDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return contents.compactMap { dir in
            let file = dir.appendingPathComponent("journal.json")
            guard let data = try? Data(contentsOf: file) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(ExpeditionJournal.self, from: data)
        }.sorted { $0.startDate > $1.startDate }
    }

    func delete(id: String) {
        let dir = journalDir(for: id)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Media Storage

    /// Save media file (photo/audio/video) to expedition's media directory
    func saveMedia(
        data: Data,
        filename: String,
        journalId: String,
        dayNumber: Int
    ) -> URL? {
        let mediaDir = journalDir(for: journalId)
            .appendingPathComponent("media/day\(dayNumber)", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileURL = mediaDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Save a UIImage as JPEG
    func savePhoto(
        _ image: UIImage,
        journalId: String,
        dayNumber: Int,
        quality: CGFloat = 0.85
    ) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }

        let filename = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
        let _ = saveMedia(data: data, filename: filename, journalId: journalId, dayNumber: dayNumber)
        return filename
    }

    /// Get URL for a media file
    func mediaURL(journalId: String, dayNumber: Int, filename: String) -> URL {
        journalDir(for: journalId)
            .appendingPathComponent("media/day\(dayNumber)/\(filename)")
    }

    /// List all media files for a day
    func mediaFiles(journalId: String, dayNumber: Int) -> [URL] {
        let mediaDir = journalDir(for: journalId)
            .appendingPathComponent("media/day\(dayNumber)")
        return (try? FileManager.default.contentsOfDirectory(
            at: mediaDir, includingPropertiesForKeys: [.creationDateKey]
        )) ?? []
    }

    // MARK: - Garmin GPX Import

    /// Save imported GPX file from Garmin 810
    func saveGPX(data: Data, journalId: String, dayNumber: Int) -> String {
        let gpsDir = journalDir(for: journalId)
            .appendingPathComponent("gps", isDirectory: true)
        try? FileManager.default.createDirectory(at: gpsDir, withIntermediateDirectories: true)

        let filename = "day\(dayNumber).gpx"
        try? data.write(to: gpsDir.appendingPathComponent(filename))
        return filename
    }

    func gpxURL(journalId: String, dayNumber: Int) -> URL {
        journalDir(for: journalId).appendingPathComponent("gps/day\(dayNumber).gpx")
    }

    // MARK: - Contributions (iCloud 8o7/ folder)

    /// Save a contribution file
    func saveContribution(data: Data, filename: String, journalId: String) -> URL? {
        let contribDir = journalDir(for: journalId)
            .appendingPathComponent("contributions", isDirectory: true)
        try? FileManager.default.createDirectory(at: contribDir, withIntermediateDirectories: true)

        let fileURL = contribDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Scan iCloud 8o7/ folder for new media files not yet imported
    func scanICloudDropZone(existingFilenames: Set<String>) -> [(url: URL, filename: String)] {
        guard let dropZone = iCloudDropZone else { return [] }

        let extensions = ["jpg", "jpeg", "png", "heic", "mov", "mp4", "m4a", "mp3"]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dropZone, includingPropertiesForKeys: [.creationDateKey]
        ) else { return [] }

        return contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return extensions.contains(ext) && !existingFilenames.contains(url.lastPathComponent)
        }.map { ($0, $0.lastPathComponent) }
    }

    /// Copy a file from iCloud drop zone to local contributions
    func importFromiCloud(url: URL, journalId: String) -> URL? {
        let contribDir = journalDir(for: journalId)
            .appendingPathComponent("contributions", isDirectory: true)
        try? FileManager.default.createDirectory(at: contribDir, withIntermediateDirectories: true)

        let dest = contribDir.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    // MARK: - Export Directory

    func exportDir(journalId: String) -> URL {
        let dir = journalDir(for: journalId)
            .appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Helpers

    private func journalDir(for id: String) -> URL {
        baseDir.appendingPathComponent(id, isDirectory: true)
    }

    /// Total storage used by a journal
    func storageUsed(journalId: String) -> Int {
        let dir = journalDir(for: journalId)
        guard let enumerator = FileManager.default.enumerator(
            at: dir, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }

    func formattedStorageUsed(journalId: String) -> String {
        let bytes = storageUsed(journalId: journalId)
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
