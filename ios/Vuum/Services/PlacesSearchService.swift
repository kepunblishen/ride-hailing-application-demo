import Foundation

/// Place autocomplete / details for pickup & drop-off search.
///
/// Strategy (no Places SDK required):
/// 1. When `MapBootstrap` has a usable `VUUM_GOOGLE_MAPS_API_KEY`, call Places API (New)
///    over HTTPS with session tokens (`places:autocomplete` → Place Details).
/// 2. Otherwise — or on network/API failure — fall back to the local market catalog
///    (`MockPlaces`) with light fuzzy matching.
///
/// Keys are never hard-coded; enable **Places API (New)** on the same Cloud project
/// as Maps when live autocomplete is desired. See `docs/GOOGLE_MAPS_SETUP.md`.
enum PlacesSearchService {
    struct PlaceSuggestion: Identifiable, Equatable {
        let id: String
        let primaryText: String
        let secondaryText: String
        /// Google place resource id (`places/…`) when from Places API; nil for local hits.
        let googlePlaceID: String?
        /// Already-resolved catalog place (local fallback or cached resolve).
        let place: Place?

        var isRemote: Bool { googlePlaceID != nil }

        static func local(_ place: Place) -> PlaceSuggestion {
            PlaceSuggestion(
                id: place.id,
                primaryText: place.name,
                secondaryText: place.subtitle,
                googlePlaceID: nil,
                place: place
            )
        }
    }

    private static let session = SessionState()

    /// Start a new Autocomplete billing session (fresh UUID). Call when the search field gains focus
    /// or the query is cleared after a selection.
    static func beginSession() {
        session.resetToken()
    }

    /// Discard the current session token without a Place Details call (abandoned search).
    static func abandonSession() {
        session.clearToken()
    }

    /// Alias for clearing the session after Place Details (or when leaving search).
    static func endSession() {
        session.clearToken()
    }

    /// Autocomplete suggestions for `query`. Debounce in the UI (~250–350 ms).
    static func autocomplete(
        query: String,
        bias: GeoPoint? = nil,
        market: AppLocale.Market = AppLocale.current
    ) async -> [PlaceSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        MapBootstrap.configureIfNeeded()
        if MapBootstrap.hasAPIKey, let key = MapBootstrap.resolvedAPIKey() {
            do {
                let remote = try await fetchRemoteSuggestions(
                    query: trimmed,
                    bias: bias ?? MockPlaces.defaultCenter(for: market).coordinate,
                    market: market,
                    apiKey: key
                )
                if !remote.isEmpty { return remote }
            } catch {
                #if DEBUG
                print("[Vuum] Places autocomplete failed — using local catalog: \(error.localizedDescription)")
                #endif
            }
        }

        return localSuggestions(query: trimmed, market: market)
    }

    /// Resolve a suggestion to a full `Place` (coordinates + address). Ends the Places session
    /// when the suggestion came from Google Autocomplete.
    static func resolve(_ suggestion: PlaceSuggestion) async -> Place? {
        if let place = suggestion.place {
            session.clearToken()
            return place
        }
        guard let googleID = suggestion.googlePlaceID else { return nil }

        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey, let key = MapBootstrap.resolvedAPIKey() else {
            session.clearToken()
            return nil
        }

        do {
            let place = try await fetchPlaceDetails(
                placeResourceName: googleID,
                fallbackName: suggestion.primaryText,
                fallbackSubtitle: suggestion.secondaryText,
                apiKey: key
            )
            session.clearToken()
            return place
        } catch {
            #if DEBUG
            print("[Vuum] Place Details failed: \(error.localizedDescription)")
            #endif
            session.clearToken()
            return nil
        }
    }

    // MARK: - Local catalog

    static func localSuggestions(
        query: String,
        market: AppLocale.Market,
        limit: Int = 12
    ) -> [PlaceSuggestion] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let catalog = MockPlaces.destinations(for: market)
        let scored: [(Place, Int)] = catalog.compactMap { place in
            let name = place.name.lowercased()
            let subtitle = place.subtitle.lowercased()
            var score = 0
            if name == q { score = 100 }
            else if name.hasPrefix(q) { score = 80 }
            else if name.contains(q) { score = 60 }
            else if subtitle.contains(q) { score = 40 }
            else {
                let tokens = q.split(separator: " ")
                let hit = tokens.contains { name.contains($0) || subtitle.contains($0) }
                if hit { score = 25 }
                else if fuzzyContains(haystack: name, needle: q) { score = 15 }
                else { return nil }
            }
            return (place, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { PlaceSuggestion.local($0.0) }
    }

    /// Typo-tolerant substring: allow one edit distance per ~4 chars of needle.
    private static func fuzzyContains(haystack: String, needle: String) -> Bool {
        guard needle.count >= 3 else { return haystack.contains(needle) }
        if haystack.contains(needle) { return true }
        let maxDist = max(1, needle.count / 4)
        let h = Array(haystack)
        let n = Array(needle)
        guard h.count >= n.count else { return levenshtein(h, n) <= maxDist }
        for i in 0...(h.count - n.count) {
            let slice = Array(h[i..<(i + n.count)])
            if levenshtein(slice, n) <= maxDist { return true }
        }
        return false
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        let m = a.count
        let n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var prev = Array(0...n)
        var cur = Array(repeating: 0, count: n + 1)
        for i in 1...m {
            cur[0] = i
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            prev = cur
        }
        return prev[n]
    }

    // MARK: - Places API (New) REST

    private static func fetchRemoteSuggestions(
        query: String,
        bias: GeoPoint,
        market: AppLocale.Market,
        apiKey: String
    ) async throws -> [PlaceSuggestion] {
        let token = session.ensureToken()
        let url = URL(string: "https://places.googleapis.com/v1/places:autocomplete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": query,
            "sessionToken": token,
            "languageCode": "en",
            "includedRegionCodes": market == .kenya ? ["ke"] : ["cd"],
            "locationBias": [
                "circle": [
                    "center": [
                        "latitude": bias.latitude,
                        "longitude": bias.longitude,
                    ],
                    "radius": TripGeo.biasRadiusMeters(for: market),
                ],
            ],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PlacesError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PlacesError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
        return (decoded.suggestions ?? []).compactMap { item in
            guard let pred = item.placePrediction else { return nil }
            let main = pred.structuredFormat?.mainText?.text
                ?? pred.text?.text
                ?? "Place"
            let secondary = pred.structuredFormat?.secondaryText?.text ?? ""
            let resource = pred.place ?? (pred.placeId.map { "places/\($0)" })
            guard let resource else { return nil }
            return PlaceSuggestion(
                id: resource,
                primaryText: main,
                secondaryText: secondary,
                googlePlaceID: resource,
                place: nil
            )
        }
    }

    private static func fetchPlaceDetails(
        placeResourceName: String,
        fallbackName: String,
        fallbackSubtitle: String,
        apiKey: String
    ) async throws -> Place {
        let token = session.currentToken
        var components = URLComponents(
            string: "https://places.googleapis.com/v1/\(placeResourceName)"
        )!
        if let token {
            components.queryItems = [URLQueryItem(name: "sessionToken", value: token)]
        }
        guard let url = components.url else { throw PlacesError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "id,displayName,formattedAddress,location",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw PlacesError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let details = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
        let lat = details.location?.latitude ?? 0
        let lon = details.location?.longitude ?? 0
        let name = details.displayName?.text ?? fallbackName
        let subtitle = details.formattedAddress ?? fallbackSubtitle
        let id = details.id ?? placeResourceName.replacingOccurrences(of: "places/", with: "")
        return Place(
            id: id,
            name: name,
            subtitle: subtitle,
            coordinate: GeoPoint(latitude: lat, longitude: lon)
        )
    }

    // MARK: - Types

    private enum PlacesError: Error {
        case invalidResponse
        case httpStatus(Int)
    }

    private final class SessionState: @unchecked Sendable {
        private let lock = NSLock()
        private var token: String?

        var currentToken: String? {
            lock.lock()
            defer { lock.unlock() }
            return token
        }

        func ensureToken() -> String {
            lock.lock()
            defer { lock.unlock() }
            if let token { return token }
            let fresh = UUID().uuidString
            token = fresh
            return fresh
        }

        func resetToken() {
            lock.lock()
            token = UUID().uuidString
            lock.unlock()
        }

        func clearToken() {
            lock.lock()
            token = nil
            lock.unlock()
        }
    }

    private struct AutocompleteResponse: Decodable {
        let suggestions: [SuggestionItem]?
    }

    private struct SuggestionItem: Decodable {
        let placePrediction: PlacePrediction?
    }

    private struct PlacePrediction: Decodable {
        let place: String?
        let placeId: String?
        let text: FormattableText?
        let structuredFormat: StructuredFormat?
    }

    private struct StructuredFormat: Decodable {
        let mainText: FormattableText?
        let secondaryText: FormattableText?
    }

    private struct FormattableText: Decodable {
        let text: String?
    }

    private struct PlaceDetailsResponse: Decodable {
        let id: String?
        let displayName: FormattableText?
        let formattedAddress: String?
        let location: LatLng?
    }

    private struct LatLng: Decodable {
        let latitude: Double?
        let longitude: Double?
    }
}
