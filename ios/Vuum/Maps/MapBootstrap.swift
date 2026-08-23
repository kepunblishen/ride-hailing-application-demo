import Foundation

#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// Google Maps SDK bootstrap.
///
/// Key resolution order (first non-empty wins):
/// 1. Process environment `VUUM_GOOGLE_MAPS_API_KEY` (Xcode scheme / CI process env)
/// 2. Info.plist `VUUM_GOOGLE_MAPS_API_KEY` (Secrets.xcconfig / xcodebuild substitution)
/// 3. Info.plist `GMSApiKey` (legacy / alternate inject)
enum MapBootstrap {
    private(set) static var isConfigured = false
    private static var didAttempt = false

    /// True when a usable key was found (whether or not GoogleMaps linked).
    private(set) static var hasAPIKey = false

    static func configureIfNeeded() {
        guard !didAttempt else { return }
        didAttempt = true

        let key = resolvedAPIKey()
        guard let key, isUsableKey(key) else {
            hasAPIKey = false
            #if DEBUG
            print("[Vuum] Maps API key missing — set VUUM_GOOGLE_MAPS_API_KEY (scheme, Info.plist, or Secrets.xcconfig).")
            #endif
            return
        }

        hasAPIKey = true

        #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(key)
        isConfigured = true
        #else
        #if DEBUG
        print("[Vuum] GoogleMaps package not linked — map UI unavailable.")
        #endif
        #endif
    }

    static func resolvedAPIKey() -> String? {
        let candidates: [String?] = [
            ProcessInfo.processInfo.environment["VUUM_GOOGLE_MAPS_API_KEY"],
            Bundle.main.object(forInfoDictionaryKey: "VUUM_GOOGLE_MAPS_API_KEY") as? String,
            Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
        ]
        for raw in candidates {
            let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    /// Shared by Maps bootstrap, Places HTTPS, and Routes HTTPS clients.
    static func isUsableAPIKey(_ key: String) -> Bool {
        let placeholders: Set<String> = [
            "YOUR_GOOGLE_MAPS_API_KEY",
            "$(VUUM_GOOGLE_MAPS_API_KEY)",
            "$(GMSApiKey)",
            "REPLACE_ME",
        ]
        return !placeholders.contains(key)
    }

    private static func isUsableKey(_ key: String) -> Bool {
        isUsableAPIKey(key)
    }
}
