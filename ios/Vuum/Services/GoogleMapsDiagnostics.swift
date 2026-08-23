import Foundation

/// DEBUG / gated diagnostics for Maps credentials and recent Google HTTPS calls.
/// Never stores or prints the raw API key.
@MainActor
final class GoogleMapsDiagnostics: ObservableObject {
    static let shared = GoogleMapsDiagnostics()

    private enum Keys {
        /// When true, `VuumMapView` skips bundled JSON `mapStyle` (default Google basemap).
        static let useDefaultBasemap = "vuum.maps.useDefaultBasemapStyle"
    }

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
    /// Last JSON map-style apply result (`applied` / `cleared` / `failed:…` / `skipped`).
    @Published private(set) var lastMapStyleOutcome: String?
    /// Temporary A/B: skip brand JSON styles to rule out style-induced blank basemaps.
    @Published var useDefaultBasemapStyle: Bool {
        didSet { UserDefaults.standard.set(useDefaultBasemapStyle, forKey: Keys.useDefaultBasemap) }
    }

    private let maxLogEntries = 24

    init() {
        useDefaultBasemapStyle = UserDefaults.standard.bool(forKey: Keys.useDefaultBasemap)
    }

    /// Boolean only — never the key value or a suffix.
    var keyPresenceLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.hasAPIKey ? "Yes" : "No"
    }

    var mapsSDKConfiguredLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.isConfigured ? "Yes" : "No"
    }

    var hasUsableKeyLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.hasAPIKey ? "Yes" : "No"
    }

    var liveMapSurfaceLabel: String {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.surface == .live ? "GMSMapView" : "Unavailable plane"
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

    /// One-line hypothesis for white basemap + visible overlays (markers/polylines).
    var blankTilesHypothesis: String {
        MapBootstrap.configureIfNeeded()
        if !MapBootstrap.hasAPIKey {
            return "No usable key → unavailable plane (not GMS tiles)."
        }
        if !MapBootstrap.isConfigured {
            return "Key present but Maps SDK not linked/configured."
        }
        return "Key+SDK OK; white+polyline usually means tiles denied (billing, Maps SDK for iOS, or bundle ID). Not cloud Map ID / no-code styling — app uses JSON mapStyle, not mapID."
    }

    func noteMapStyleOutcome(_ outcome: String) {
        lastMapStyleOutcome = outcome
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
        lastMapStyleOutcome = nil
    }
}
