//
//  PermissionService.swift
//  StoneBC
//
//  Centralized permission status tracker for onboarding and feature gating.
//

import CoreLocation
import CoreMotion
import HealthKit
import AVFoundation

@Observable
class PermissionService: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionService()

    var locationStatus: CLAuthorizationStatus = .notDetermined
    var healthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var healthKitAuthorized = false
    var microphoneGranted = false
    // Recomputed on each read so the onboarding page picks up granted state
    // immediately after the system sheet closes.
    var motionGranted: Bool {
        CMMotionActivityManager.authorizationStatus() == .authorized
    }

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private let altimeter = CMAltimeter()

    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    // MARK: - Location

    var locationGranted: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }

    // MARK: - Microphone

    func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneGranted = granted
            }
        }
    }

    // MARK: - Motion

    /// Triggers the iOS Motion & Fitness permission sheet. Starts relative
    /// altitude updates briefly (iOS gates this behind the NSMotionUsageDescription
    /// prompt) and stops immediately on the first callback so there's no
    /// sustained sensor cost.
    func requestMotion() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak altimeter] _, _ in
            altimeter?.stopRelativeAltitudeUpdates()
        }
    }

    // MARK: - HealthKit

    func requestHealthKit() async {
        guard healthKitAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            healthKitAuthorized = true
        } catch {
            healthKitAuthorized = false
        }
    }
}
