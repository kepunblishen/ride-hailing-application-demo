import Foundation

/// Shared headers for Google Maps Platform **HTTPS** (Places / Routes / Directions / Geocoding).
/// Maps SDK uses `GMSServices.provideAPIKey` separately — do not route SDK traffic through this helper.
enum GoogleMapsREST {
    /// Places (New) / Routes style: API key + iOS bundle header (+ optional field mask).
    static func applyAPIKeyHeaders(
        to request: inout URLRequest,
        apiKey: String,
        fieldMask: String? = nil
    ) {
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        MapBootstrap.applyIOSBundleIdentifierHeader(to: &request)
        if let fieldMask, !fieldMask.isEmpty {
            request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        }
    }

    /// Legacy JSON endpoints that already put `key=` in the query string still send the bundle header
    /// so iOS-restricted keys can accept the request when Google checks client identity.
    static func applyBundleIdentifier(to request: inout URLRequest) {
        MapBootstrap.applyIOSBundleIdentifierHeader(to: &request)
    }
}
