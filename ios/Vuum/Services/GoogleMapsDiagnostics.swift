import Foundation

/// DEBUG / gated diagnostics for Maps credentials and recent Google HTTPS calls.
/// Never stores or prints the raw API key.
@MainActor
final class GoogleMapsDiagnostics: ObservableObject {
    static let shared = GoogleMapsDiagnostics()

    struct RequestLogEntry: Identifiable, Equatable {
        let id = UUID()
        let api: String
        let httpStatus: Int?
        let durationMs: Int
        let attemptCount: Int
        /// `ok` or a `GoogleAPIError.diagnosticCode`.
        let outcome: String
        let timestamp: Date
    }

    @Published private(set) var lastErrorCode: String?
    @Published private(set) var lastSuccessAPI: String?
    @Published private(set) var lastRiderMessage: String?
    @Published private(set) var recentRequests: [RequestLogEntry] = []

    private let maxLogEntries = 24

    /// Present/absent with masked suffix — never the full key.
    var keyPresenceLabel: String {
        MapBootstrap.configureIfNeeded()
        guard let key = MapBootstrap.resolvedAPIKey() else { return "Absent" }
        let suffix = String(key.suffix(min(4, key.count)))
        return "Present · …\(suffix)"
    }

    var mapsSDKConfiguredLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.isConfigured ? "Yes" : "No"
    }

    var hasUsableKeyLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.hasAPIKey ? "Yes" : "No"
    }

    var bundleID: String {
        Bundle.main.bundleIdentifier ?? MapBootstrap.iosBundleIdentifier
    }

    var buildConfiguration: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    func record(
        api: GoogleAPIKind,
        httpStatus: Int?,
        durationMs: Int,
        attemptCount: Int,
        error: GoogleAPIError?
    ) {
        if let error {
            lastErrorCode = error.diagnosticCode
            lastRiderMessage = error.riderMessage
        } else {
            lastSuccessAPI = api.rawValue
        }

        #if DEBUG
        let entry = RequestLogEntry(
            api: api.rawValue,
            httpStatus: httpStatus,
            durationMs: durationMs,
            attemptCount: attemptCount,
            outcome: error?.diagnosticCode ?? "ok",
            timestamp: Date()
        )
        recentRequests.insert(entry, at: 0)
        if recentRequests.count > maxLogEntries {
            recentRequests = Array(recentRequests.prefix(maxLogEntries))
        }
        let statusPart = httpStatus.map(String.init) ?? "—"
        print(
            "[Vuum][Maps] \(api.rawValue) status=\(statusPart) \(durationMs)ms attempts=\(attemptCount) \(entry.outcome)"
        )
        #endif
    }

    /// Records a non-HTTP Google status failure (e.g. Directions `REQUEST_DENIED`).
    func noteError(_ error: GoogleAPIError, api: GoogleAPIKind? = nil) {
        lastErrorCode = error.diagnosticCode
        lastRiderMessage = error.riderMessage
        #if DEBUG
        if let api {
            let entry = RequestLogEntry(
                api: api.rawValue,
                httpStatus: nil,
                durationMs: 0,
                attemptCount: 1,
                outcome: error.diagnosticCode,
                timestamp: Date()
            )
            recentRequests.insert(entry, at: 0)
            if recentRequests.count > maxLogEntries {
                recentRequests = Array(recentRequests.prefix(maxLogEntries))
            }
        }
        #endif
    }

    func clearRequestLog() {
        recentRequests = []
        lastErrorCode = nil
        lastSuccessAPI = nil
        lastRiderMessage = nil
    }
}
