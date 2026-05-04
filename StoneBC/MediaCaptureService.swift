//
//  MediaCaptureService.swift
//  StoneBC
//
//  Camera, voice memo, and video capture wrappers for expedition journaling.
//  Handles AVAudioRecorder for voice memos and coordinates PHPicker for photos.
//

import AVFoundation
import CoreLocation
import UIKit

@Observable
class MediaCaptureService {
    var isRecordingAudio = false
    var audioRecordingDuration: TimeInterval = 0
    var error: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioTimer: Timer?
    private var currentAudioURL: URL?

    // MARK: - Voice Memo

    static func voiceMemoFilename(at date: Date = Date()) -> String {
        "voice_\(Int(date.timeIntervalSince1970)).m4a"
    }

    static func formattedDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Start recording a voice memo, returns filename
    func startVoiceMemo(journalId: String, dayNumber: Int) -> String? {
        let filename = Self.voiceMemoFilename()

        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docDir.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileURL = mediaDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            currentAudioURL = fileURL
            isRecordingAudio = true
            audioRecordingDuration = 0

            audioTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.audioRecordingDuration = self?.audioRecorder?.currentTime ?? 0
            }

            return filename
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Stop recording voice memo
    func stopVoiceMemo() {
        audioRecorder?.stop()
        audioRecorder = nil
        audioTimer?.invalidate()
        audioTimer = nil
        isRecordingAudio = false

        // Reset audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    var formattedRecordingDuration: String {
        Self.formattedDuration(audioRecordingDuration)
    }

    // MARK: - Photo from UIImage

    /// Save a captured photo, returns filename
    func savePhoto(
        _ image: UIImage,
        journalId: String,
        dayNumber: Int,
        quality: CGFloat = 0.85
    ) -> String? {
        guard let data = image.jpegData(compressionQuality: quality) else { return nil }

        let filename = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docDir.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileURL = mediaDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            return nil
        }
    }

    // MARK: - Video

    /// Save a video file from a temporary URL, returns filename
    func saveVideo(from tempURL: URL, journalId: String, dayNumber: Int) -> String? {
        let filename = "VID_\(Int(Date().timeIntervalSince1970)).mov"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docDir.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileURL = mediaDir.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: tempURL, to: fileURL)
            return filename
        } catch {
            return nil
        }
    }

    /// Save selected video data from PhotosPicker, returns filename
    func saveVideo(data: Data, journalId: String, dayNumber: Int) -> String? {
        let filename = "VID_\(Int(Date().timeIntervalSince1970)).mov"
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let mediaDir = docDir.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let fileURL = mediaDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            return nil
        }
    }

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail for a photo
    static func thumbnail(for imageURL: URL, maxSize: CGFloat = 200) -> UIImage? {
        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else { return nil }

        let scale = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
