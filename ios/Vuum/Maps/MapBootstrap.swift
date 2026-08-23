import Foundation

#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// Google Maps SDK bootstrap.
///
/// Key resolution order (first **usable** non-placeholder wins):
/// 1. Process environment `VUUM_GOOGLE_MAPS_API_KEY` (Xcode scheme Run env / CI process)
/// 2. Info.plist `VUUM_GOOGLE_MAPS_API_KEY` (`Secrets.xcconfig` / `xcodebuild` substitution)
/// 3. Info.plist `GMSApiKey` (same build setting; legacy alias)
///
/// Build-time injection: `ios/Vuum/Config/Vuum.xcconfig` defaults to a placeholder,
/// optionally overridden by gitignored `ios/Secrets.xcconfig` (Codemagic writes this
/// from secure env). Bundle ID for key restriction: `com.vuum.app`.
///
/// Presentation builds may use one key for Maps SDK + client REST (Places / Routes /
/// Directions). Split SDK vs REST keys later if a backend proxy or separate Cloud
/// credentials are introduced — see `docs/GOOGLE_MAPS_SETUP.md`.
enum MapBootstrap {
    /// Must match Google Cloud **iOS apps** restriction and `PRODUCT_BUNDLE_IDENTIFIER`.
    static let iosBundleIdentifier = "com.vuum.app"

    /// Header Google expects on Maps Platform REST from an iOS-restricted key.
    static let iosBundleIdentifierHeader = "X-Ios-Bundle-Identifier"

    private(set) static var isConfigured = false
    private static var didAttempt = false

    /// True when a usable key was found (whether or not GoogleMaps linked).
    private(set) static var hasAPIKey = false

    /// Applies `X-Ios-Bundle-Identifier: com.vuum.app` so iOS-restricted keys work for HTTPS.
    static func applyIOSBundleIdentifierHeader(to request: inout URLRequest) {
        request.setValue(iosBundleIdentifier, forHTTPHeaderField: iosBundleIdentifierHeader)
    }

    /// Live `GMSMapView` vs rider-facing unavailable plane. Chosen once at launch
    /// (`configureIfNeeded`); inject a key and rebuild / relaunch to switch to live tiles.
    enum Surface {
        case live
        case unavailable
    }

    static var surface: Surface {
        configureIfNeeded()
        return isConfigured ? .live : .unavailable
    }

    static func configureIfNeeded() {
        guard !didAttempt else { return }
        didAttempt = true

        guard let key = resolvedAPIKey() else {
            hasAPIKey = false
            #if DEBUG
            print("[Vuum] Maps API key missing — set VUUM_GOOGLE_MAPS_API_KEY (Secrets.xcconfig, scheme env, or Codemagic).")
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

    /// First usable key from resolution order, or `nil` if only missing/placeholders.
    static func resolvedAPIKey() -> String? {
        let candidates: [String?] = [
            ProcessInfo.processInfo.environment["VUUM_GOOGLE_MAPS_API_KEY"],
            Bundle.main.object(forInfoDictionaryKey: "VUUM_GOOGLE_MAPS_API_KEY") as? String,
            Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
        ]
        for raw in candidates {
            let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, isUsableAPIKey(trimmed) else { continue }
            return trimmed
        }
        return nil
    }

    /// Shared by Maps bootstrap, Places HTTPS, and Routes HTTPS clients.
    /// Never log the key value.
    static func isUsableAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Unsubstituted Xcode build setting / Info.plist macros.
        if trimmed.contains("$(") { return false }

        let upper = trimmed.uppercased()
        let placeholders: Set<String> = [
            "YOUR_GOOGLE_MAPS_API_KEY",
            "REPLACE_ME",
            "CHANGEME",
            "INSERT_API_KEY",
            "INSERT_KEY_HERE",
            "API_KEY_HERE",
            "NONE",
            "NULL",
            "UNDEFINED",
        ]
        if placeholders.contains(upper) { return false }
        // Reject truncated / bleed-through strings; Google keys are long.
        // A revoked Cloud key that still looks valid boots the SDK; Places/Routes
        // then fail closed to local fallbacks (no raw Google errors in UI).
        if trimmed.count < 20 { return false }
        return true
    }
}