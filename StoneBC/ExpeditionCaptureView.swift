//
//  ExpeditionCaptureView.swift
//  StoneBC
//
//  During-ride capture UI — quick-log sheet for text notes, photos,
//  voice memos, and video. Auto-attaches GPS coordinate and timestamp.
//

import SwiftUI
import PhotosUI
import CoreLocation

struct ExpeditionCaptureView: View {
    let journalId: String
    let dayNumber: Int
    let currentLocation: CLLocationCoordinate2D?
    let onEntryAdded: (JournalEntry) -> Void

    @State private var noteText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var mediaCapture = MediaCaptureService()
    @State private var recordingFilename: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Location indicator
                if let loc = currentLocation {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(BCColors.brandGreen)
                        Text(String(format: "%.4f, %.4f", loc.latitude, loc.longitude))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(Date(), style: .time)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Text entry
                TextField("What are you seeing? Trail conditions, landmarks, thoughts...", text: $noteText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...8)
                    .padding(.horizontal)

                // Photo preview
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topTrailing) {
                            Button {
                                capturedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(8)
                        }
                        .padding(.horizontal)
                }

                // Voice memo indicator
                if mediaCapture.isRecordingAudio {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                        Text("Recording \(mediaCapture.formattedRecordingDuration)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                        Spacer()
                        Button("Stop") {
                            mediaCapture.stopVoiceMemo()
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                HStack(spacing: 20) {
                    // Camera
                    Button {
                        showCamera = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22))
                            Text("Photo")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BCColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Photo Library
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 22))
                            Text("Library")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BCColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Voice Memo
                    Button {
                        if mediaCapture.isRecordingAudio {
                            mediaCapture.stopVoiceMemo()
                        } else {
                            recordingFilename = mediaCapture.startVoiceMemo(
                                journalId: journalId,
                                dayNumber: dayNumber
                            )
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: mediaCapture.isRecordingAudio ? "stop.circle.fill" : "mic.fill")
                                .font(.system(size: 22))
                                .foregroundColor(mediaCapture.isRecordingAudio ? .red : .primary)
                            Text("Voice")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BCColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Save button
                Button {
                    saveEntry()
                } label: {
                    Text("LOG ENTRY")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(hasContent ? BCColors.brandBlue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!hasContent)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("DAY \(dayNumber)")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    capturedImage = image
                }
            }
            .onChange(of: selectedPhoto) {
                loadPickerPhoto()
            }
        }
        .presentationDetents([.large])
    }

    private var hasContent: Bool {
        !noteText.trimmingCharacters(in: .whitespaces).isEmpty ||
        capturedImage != nil ||
        recordingFilename != nil
    }

    private func saveEntry() {
        // Save photo if captured
        var photoFilename: String?
        if let image = capturedImage {
            photoFilename = mediaCapture.savePhoto(
                image,
                journalId: journalId,
                dayNumber: dayNumber
            )
        }

        // Stop recording if active
        if mediaCapture.isRecordingAudio {
            mediaCapture.stopVoiceMemo()
        }

        // Determine media type
        let mediaType: MediaType?
        let filename: String?
        if let photo = photoFilename {
            mediaType = .photo
            filename = photo
        } else if let audio = recordingFilename {
            mediaType = .audio
            filename = audio
        } else {
            mediaType = nil
            filename = nil
        }

        let entry = JournalEntry(
            text: noteText.isEmpty ? nil : noteText,
            mediaFilename: filename,
            mediaType: mediaType,
            source: .iphone,
            coordinate: currentLocation
        )

        onEntryAdded(entry)
        dismiss()
    }

    private func loadPickerPhoto() {
        guard let item = selectedPhoto else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                capturedImage = image
            }
        }
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
