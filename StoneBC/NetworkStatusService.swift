//
//  NetworkStatusService.swift
//  StoneBC
//
//  Lightweight `NWPathMonitor` wrapper. Observed by views to drive an
//  "OFFLINE" pill on the navigation HUD and to gate WeatherKit / WordPress /
//  Trailforks calls. One instance per app launch — owned by `StoneBCApp` and
//  injected into the environment.
//

import Foundation
import Network

@Observable
final class NetworkStatusService {
    static let shared = NetworkStatusService()

    /// True when at least one path is .satisfied. Defaults to true so first
    /// launch doesn't render an "OFFLINE" pill before the monitor reports.
    var isOnline: Bool = true

    /// True when the active path is a cellular interface — surfacing this lets
    /// us skip heavy tile prefetches on metered connections in P1.
    var isCellular: Bool = false

    /// True when the active path is constrained or expensive — Apple's signal
    /// for Low Data Mode / metered Wi-Fi.
    var isExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.traddiff.StoneBC.network", qos: .utility)
    private var didStart = false

    private init() {}

    /// Idempotent — call from `StoneBCApp` once at launch.
    func start() {
        guard !didStart else { return }
        didStart = true

        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let cellular = path.usesInterfaceType(.cellular)
            let expensive = path.isExpensive || path.isConstrained

            DispatchQueue.main.async {
                guard let self else { return }
                self.isOnline = online
                self.isCellular = cellular
                self.isExpensive = expensive
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard didStart else { return }
        monitor.cancel()
        didStart = false
    }
}
