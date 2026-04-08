//
//  PermissionService.swift
//  StoneBC
//
//  Centralized permission status tracker for onboarding and feature gating.
//

import CoreLocation
import HealthKit
import AVFoundation

@Observable
class PermissionService: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionService()

    var locationStatus: CLAuthorizationStatus = .notDetermined
    var healthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var healthKitAuthorized = false

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()

    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus
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
