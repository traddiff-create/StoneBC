//
//  PermissionService.swift
//  StoneBC
//
//  Centralized permission status tracker for onboarding and feature gating.
//

import AVFoundation
import CoreLocation
import CoreMotion
import HealthKit
import MultipeerConnectivity
import Photos
import UserNotifications

@Observable
class PermissionService: NSObject, CLLocationManagerDelegate {
    static let shared = PermissionService()

    var locationStatus: CLAuthorizationStatus = .notDetermined
    var healthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    var healthKitAuthorized = false
    var microphoneGranted = false
    var microphoneDenied = false
    var cameraGranted = false
    var cameraDenied = false
    var photosAddOnlyGranted = false
    var photosAddOnlyDenied = false
    var notificationsGranted = false
    var notificationsDenied = false
    var localNetworkRequested = false
    var localNetworkProbeActive = false
    var motionProbeCompleted = false

    // Recomputed on each read so the onboarding page picks up granted state
    // immediately after the system sheet closes.
    var motionGranted: Bool {
        CMMotionActivityManager.authorizationStatus() == .authorized
    }

    var motionAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    var locationDenied: Bool {
        locationStatus == .denied || locationStatus == .restricted
    }

    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private let altimeter = CMAltimeter()
    private let localNetworkPromptedKey = "localNetworkPermissionRequested"
    private let localNetworkPeerID = MCPeerID(displayName: "StoneBC")
    private var localNetworkAdvertiser: MCNearbyServiceAdvertiser?
    private var localNetworkBrowser: MCNearbyServiceBrowser?

    override init() {
        super.init()
        locationManager.delegate = self
        localNetworkRequested = UserDefaults.standard.bool(forKey: localNetworkPromptedKey)
        refreshSynchronousStatuses()
        Task {
            await refreshNotificationStatus()
        }
    }

    func refreshPermissionStates() async {
        await MainActor.run {
            refreshSynchronousStatuses()
        }
        await refreshNotificationStatus()
    }

    private func refreshSynchronousStatuses() {
        locationStatus = locationManager.authorizationStatus

        let recordPermission = AVAudioApplication.shared.recordPermission
        microphoneGranted = recordPermission == .granted
        microphoneDenied = recordPermission == .denied

        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraGranted = cameraStatus == .authorized
        cameraDenied = cameraStatus == .denied || cameraStatus == .restricted

        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        photosAddOnlyGranted = photoStatus == .authorized || photoStatus == .limited
        photosAddOnlyDenied = photoStatus == .denied || photoStatus == .restricted

        if healthKitAvailable {
            healthKitAuthorized = healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
        }
    }

    // MARK: - Location

    var locationGranted: Bool {
        locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways
    }

    var locationAlwaysGranted: Bool {
        locationStatus == .authorizedAlways
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysLocation() {
        if locationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if locationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }

    // MARK: - Microphone

    func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneGranted = granted
                self.microphoneDenied = !granted
            }
        }
    }

    // MARK: - Camera

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraGranted = granted
                self.cameraDenied = !granted
            }
        }
    }

    // MARK: - Photos

    func requestPhotosAddOnly() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                self.photosAddOnlyGranted = status == .authorized || status == .limited
                self.photosAddOnlyDenied = status == .denied || status == .restricted
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
            self.motionProbeCompleted.toggle()
        }
    }

    // MARK: - Local Network

    func requestLocalNetworkProbe() {
        guard !localNetworkProbeActive else { return }

        localNetworkRequested = true
        localNetworkProbeActive = true
        UserDefaults.standard.set(true, forKey: localNetworkPromptedKey)

        let advertiser = MCNearbyServiceAdvertiser(
            peer: localNetworkPeerID,
            discoveryInfo: ["mode": "onboarding"],
            serviceType: RadioConfig.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        localNetworkAdvertiser = advertiser

        let browser = MCNearbyServiceBrowser(
            peer: localNetworkPeerID,
            serviceType: RadioConfig.serviceType
        )
        browser.delegate = self
        browser.startBrowsingForPeers()
        localNetworkBrowser = browser

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.stopLocalNetworkProbe()
        }
    }

    private func stopLocalNetworkProbe() {
        localNetworkAdvertiser?.stopAdvertisingPeer()
        localNetworkBrowser?.stopBrowsingForPeers()
        localNetworkAdvertiser = nil
        localNetworkBrowser = nil
        localNetworkProbeActive = false
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

    // MARK: - Notifications

    func requestNotifications() async {
        await EventNotificationService.shared.requestPermission()
        await refreshNotificationStatus()
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationsGranted = settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral
            notificationsDenied = settings.authorizationStatus == .denied
        }
        await EventNotificationService.shared.checkAuthorizationStatus()
    }
}

extension PermissionService: MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(false, nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        stopLocalNetworkProbe()
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {}

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        stopLocalNetworkProbe()
    }
}
