import Combine
import Foundation
import Network

/// Observes path reachability for offline / reconnect banners and retry UX.
@MainActor
final class NetworkReachability: ObservableObject {
    enum Status: Equatable {
        case online
        case offline
        case constrained
    }

    @Published private(set) var status: Status = .online
    @Published private(set) var isConnecting = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.vuum.network.monitor")
    /// When true, UI treats the path as offline regardless of NWPathMonitor (diagnostics only).
    private var forceOffline = false
    private var lastPathStatus: Status = .online

    var isReachable: Bool { status != .offline }

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    /// Diagnostics override — does not change the underlying monitor.
    func setForcedOffline(_ offline: Bool) {
        forceOffline = offline
        republish()
    }

    /// Brief “connecting…” pulse used when hubs refresh or recover from an error.
    func simulateConnecting(durationNanoseconds: UInt64 = 700_000_000) async {
        isConnecting = true
        try? await Task.sleep(nanoseconds: durationNanoseconds)
        isConnecting = false
    }

    /// Retry helper: show connecting, then succeed or surface offline.
    @discardableResult
    func retry() async -> Bool {
        await simulateConnecting()
        return isReachable
    }

    private func apply(_ path: NWPath) {
        if path.status == .satisfied {
            lastPathStatus = path.isConstrained || path.isExpensive ? .constrained : .online
        } else {
            lastPathStatus = .offline
        }
        republish()
    }

    private func republish() {
        status = forceOffline ? .offline : lastPathStatus
    }
}
