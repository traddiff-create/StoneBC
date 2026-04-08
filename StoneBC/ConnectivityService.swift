//
//  ConnectivityService.swift
//  StoneBC
//
//  NWPathMonitor wrapper — detects online/offline state for the app
//

import Network
import Foundation

@Observable
class ConnectivityService {
    static let shared = ConnectivityService()

    var isConnected: Bool = true
    var connectionType: ConnectionType = .unknown

    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Cellular"
        case wired = "Wired"
        case unknown = "Unknown"
        case none = "No Connection"
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.traddiff.StoneBC.connectivity")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }

    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wired }
        if path.status == .satisfied { return .unknown }
        return .none
    }
}
