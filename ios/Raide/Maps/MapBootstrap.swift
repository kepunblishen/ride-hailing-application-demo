import Foundation

#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// Google Maps SDK bootstrap.
///
/// Provide a key via scheme env `RAIDE_GOOGLE_MAPS_API_KEY` or Info.plist `GMSApiKey`.
enum MapBootstrap {
    private(set) static var isConfigured = false
    private static var didAttempt = false

    static func configureIfNeeded() {
        guard !didAttempt else { return }
        didAttempt = true

        let key = ProcessInfo.processInfo.environment["RAIDE_GOOGLE_MAPS_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String
            ?? ""

        guard !key.isEmpty, key != "YOUR_GOOGLE_MAPS_API_KEY" else {
            #if DEBUG
            print("[Raide] Google Maps API key not set — map uses placeholder until configured.")
            #endif
            return
        }

        #if canImport(GoogleMaps)
        GMSServices.provideAPIKey(key)
        isConfigured = true
        #endif
    }
}
