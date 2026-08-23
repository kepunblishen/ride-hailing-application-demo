import Foundation

/// Optional Google Maps traffic layer + live ETA refresh policy.
///
/// Both features are **off by default** (battery / billing). They only activate when:
/// - a usable Maps API key is present (`MapBootstrap.hasAPIKey`)
/// - the rider opts in via Settings
/// - low-data / lite mode is off
enum MapTrafficSettings {
    static let trafficKey = "vuum.mapTraffic"
    static let etaRefreshKey = "vuum.etaRefresh"

    /// How often to re-query Routes/Directions for remaining ETA while a trip is live.
    static let etaRefreshIntervalSeconds: TimeInterval = 90

    /// Default: traffic overlay off (battery). Existing installs without a value stay off.
    static var isTrafficPreferenceOn: Bool {
        get { UserDefaults.standard.object(forKey: trafficKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: trafficKey) }
    }

    /// Default: periodic live ETA refresh off (battery + Routes billing).
    static var isETARefreshPreferenceOn: Bool {
        get { UserDefaults.standard.object(forKey: etaRefreshKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: etaRefreshKey) }
    }

    /// Traffic tiles require a live Maps SDK session + rider opt-in.
    static func shouldShowTrafficLayer(lowDataMode: Bool) -> Bool {
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey, MapBootstrap.isConfigured else { return false }
        guard !lowDataMode else { return false }
        return isTrafficPreferenceOn
    }

    /// Periodic traffic-aware ETA refresh — key required; opt-in; skipped in low-data.
    static func shouldRefreshETA(lowDataMode: Bool) -> Bool {
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey else { return false }
        guard !lowDataMode else { return false }
        return isETARefreshPreferenceOn
    }

    /// Low-data / lite mode forces both optional network overlays off.
    static func applyLowDataMode(_ enabled: Bool) {
        guard enabled else { return }
        isTrafficPreferenceOn = false
        isETARefreshPreferenceOn = false
    }
}
