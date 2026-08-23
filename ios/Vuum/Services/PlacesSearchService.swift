import Foundation

/// Place autocomplete / details for pickup & drop-off search.
///
/// Strategy (no Places SDK required):
/// 1. When `MapBootstrap` has a usable `VUUM_GOOGLE_MAPS_API_KEY`, call Places API (New)
///    over HTTPS with session tokens (`places:autocomplete` → Place Details).
/// 2. Otherwise — or on network/API failure — fall back to the local market catalog
///    (`MockPlaces`) with light fuzzy matching.
///
/// Session lifecycle (Google Autocomplete billing):
/// - `beginSession()` / first autocomplete → create UUID session token
/// - autocomplete keystrokes reuse the same token (UI must debounce ~300 ms)
/// - Place Details sends the same token, then clears it
/// - abandoned search / dismiss → `abandonSession()`
///
/// Cost controls: session tokens, UI debounce, bounded place-details cache, field masks
/// that include types (for icons) but never photos/reviews.
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
        /// Classification for search icons / context (Google types or local heuristics).
        let category: PlaceCategory
        /// Optional distance from search bias (e.g. `"1.2 km"`).
        let distanceHint: String?

        var isRemote: Bool { googlePlaceID != nil }

        var systemImage: String { category.systemImage }

        /// Secondary line for list rows: address, then category · distance when useful.
        var contextLine: String {
            var parts: [String] = []
            let secondary = secondaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !secondary.isEmpty { parts.append(secondary) }
            var meta: [String] = []
            if let label = category.shortLabel { meta.append(label) }
            if let distanceHint, !distanceHint.isEmpty { meta.append(distanceHint) }
            if !meta.isEmpty {
                parts.append(meta.joined(separator: " · "))
            }
            return parts.joined(separator: "\n")
        }

        /// Single-line subtitle for compact rows (address · category · distance).
        var compactSubtitle: String {
            var parts: [String] = []
            let secondary = secondaryText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !secondary.isEmpty { parts.append(secondary) }
            if let label = category.shortLabel { parts.append(label) }
            if let distanceHint, !distanceHint.isEmpty { parts.append(distanceHint) }
            return parts.joined(separator: " · ")
        }

        static func local(_ place: Place, bias: GeoPoint? = nil) -> PlaceSuggestion {
            let category = PlaceCategory.infer(
                googleTypes: nil,
                name: place.name,
                subtitle: place.subtitle,
                placeID: place.id
            )
            return PlaceSuggestion(
                id: place.id,
                primaryText: place.name,
                secondaryText: place.subtitle,
                googlePlaceID: nil,
                place: place,
                category: category,
                distanceHint: PlacesSearchService.formattedDistanceHint(from: bias, to: place.coordinate)
            )
        }
    }

    /// Outcome of an autocomplete call — UI uses `suggestions`; `remoteError` drives Retry copy.
    struct AutocompleteOutcome: Sendable {
        enum Source: String, Sendable {
            case remote
            case localCatalog
            case localAfterRemoteFailure
        }

        let suggestions: [PlaceSuggestion]
        let source: Source
        let remoteError: GoogleAPIError?

        init(suggestions: [PlaceSuggestion], source: Source, remoteError: GoogleAPIError? = nil) {
            self.suggestions = suggestions
            self.source = source
            self.remoteError = remoteError
        }
    }

    /// Recommended UI debounce before calling autocomplete (session-token cost control).
    static let recommendedDebounceMilliseconds: UInt64 = 300

    private static let session = SessionState()
    private static let detailsFieldMask =
        "id,displayName,formattedAddress,location,types,primaryType"
    private static let autocompleteFieldMask =
        "suggestions.placePrediction.place,"
        + "suggestions.placePrediction.placeId,"
        + "suggestions.placePrediction.text,"
        + "suggestions.placePrediction.structuredFormat,"
        + "suggestions.placePrediction.types"
    /// Skip remote autocomplete for 1-character queries (billing + noise); local catalog still runs.
    private static let remoteMinQueryLength = 2

    /// True when a usable Maps/Places API key is present (live path may still fail at runtime).
    static var isLivePlacesAvailable: Bool {
        MapBootstrap.configureIfNeeded()
        return MapBootstrap.hasAPIKey
    }

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

    /// Autocomplete suggestions for `query`. Debounce in the UI (~300 ms).
    static func autocomplete(
        query: String,
        bias: GeoPoint? = nil,
        market: AppLocale.Market = AppLocale.current,
        languageCode: String? = nil
    ) async -> [PlaceSuggestion] {
        await autocompleteOutcome(
            query: query,
            bias: bias,
            market: market,
            languageCode: languageCode
        ).suggestions
    }

    /// Same as `autocomplete` but reports whether results came from Google or the local catalog.
    static func autocompleteOutcome(
        query: String,
        bias: GeoPoint? = nil,
        market: AppLocale.Market = AppLocale.current,
        languageCode: String? = nil
    ) async -> AutocompleteOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AutocompleteOutcome(suggestions: [], source: .localCatalog)
        }

        MapBootstrap.configureIfNeeded()
        if trimmed.count >= remoteMinQueryLength,
           MapBootstrap.hasAPIKey,
           let key = MapBootstrap.resolvedAPIKey()
        {
            do {
                let remote = try await fetchRemoteSuggestions(
                    query: trimmed,
                    bias: bias ?? MockPlaces.defaultCenter(for: market).coordinate,
                    market: market,
                    languageCode: resolvedLanguageCode(languageCode),
                    apiKey: key
                )
                if !remote.isEmpty {
                    return AutocompleteOutcome(suggestions: remote, source: .remote)
                }
                // Empty remote → still prefer catalog so the rider always sees options.
                return AutocompleteOutcome(
                    suggestions: localSuggestions(query: trimmed, market: market, bias: bias),
                    source: .localCatalog
                )
            } catch let error as GoogleAPIError where error == .cancelled {
                return AutocompleteOutcome(suggestions: [], source: .localCatalog)
            } catch is CancellationError {
                return AutocompleteOutcome(suggestions: [], source: .localCatalog)
            } catch {
                let mapped = (error as? GoogleAPIError) ?? .invalidResponse
                if mapped == .cancelled {
                    return AutocompleteOutcome(suggestions: [], source: .localCatalog)
                }
                await GoogleMapsDiagnostics.shared.noteError(mapped, api: .placesAutocomplete)
                return AutocompleteOutcome(
                    suggestions: localSuggestions(query: trimmed, market: market, bias: bias),
                    source: .localAfterRemoteFailure,
                    remoteError: mapped
                )
            }
        }

        return AutocompleteOutcome(
            suggestions: localSuggestions(query: trimmed, market: market, bias: bias),
            source: .localCatalog
        )
    }

    /// Resolve a suggestion to a full `Place` (coordinates + address). Ends the Places session
    /// when the suggestion came from Google Autocomplete.
    static func resolve(_ suggestion: PlaceSuggestion) async -> Place? {
        if let place = suggestion.place {
            session.clearToken()
            return place
        }
        guard let googleID = suggestion.googlePlaceID else { return nil }

        if let cached = MapsRequestCache.cachedPlace(resourceName: googleID) {
            session.clearToken()
            return cached
        }

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
                languageCode: resolvedLanguageCode(nil),
                apiKey: key
            )
            MapsRequestCache.storePlace(place, resourceName: googleID)
            session.clearToken()
            return place
        } catch let error as GoogleAPIError where error == .cancelled {
            session.clearToken()
            return nil
        } catch is CancellationError {
            session.clearToken()
            return nil
        } catch {
            let mapped = (error as? GoogleAPIError) ?? .invalidResponse
            if mapped != .cancelled {
                await GoogleMapsDiagnostics.shared.noteError(mapped, api: .placesDetails)
            }
            session.clearToken()
            return nil
        }
    }

    // MARK: - Local catalog

    static func localSuggestions(
        query: String,
        market: AppLocale.Market,
        bias: GeoPoint? = nil,
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
            .map { PlaceSuggestion.local($0.0, bias: bias) }
    }

    static func formattedDistanceHint(from bias: GeoPoint?, to coordinate: GeoPoint) -> String? {
        guard let bias else { return nil }
        let meters = TripGeo.distanceMeters(from: bias, to: coordinate)
        guard meters.isFinite, meters >= 0 else { return nil }
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        let km = meters / 1000
        if km < 10 {
            return String(format: "%.1f km", km)
        }
        return "\(Int(km.rounded())) km"
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

    private static func resolvedLanguageCode(_ override: String?) -> String {
        if let override, !override.isEmpty { return override }
        switch L10n.language {
        case .english: return "en"
        case .french, .lingala: return "fr"
        case .kiswahili: return "sw"
        }
    }

    // MARK: - Places API (New) REST

    private static func fetchRemoteSuggestions(
        query: String,
        bias: GeoPoint,
        market: AppLocale.Market,
        languageCode: String,
        apiKey: String
    ) async throws -> [PlaceSuggestion] {
        let token = session.ensureToken()
        let url = URL(string: "https://places.googleapis.com/v1/places:autocomplete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        GoogleMapsREST.applyAPIKeyHeaders(
            to: &request,
            apiKey: apiKey,
            fieldMask: autocompleteFieldMask
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": query,
            "sessionToken": token,
            "languageCode": languageCode,
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

        let (data, _) = try await GoogleAPIHTTP.data(for: request, api: .placesAutocomplete)

        let decoded = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
        return (decoded.suggestions ?? []).compactMap { item in
            guard let pred = item.placePrediction else { return nil }
            let main = pred.structuredFormat?.mainText?.text
                ?? pred.text?.text
                ?? "Place"
            let secondary = pred.structuredFormat?.secondaryText?.text ?? ""
            let resource = pred.place ?? (pred.placeId.map { "places/\($0)" })
            guard let resource else { return nil }
            let category = PlaceCategory.infer(
                googleTypes: pred.types,
                name: main,
                subtitle: secondary,
                placeID: resource
            )
            return PlaceSuggestion(
                id: resource,
                primaryText: main,
                secondaryText: secondary,
                googlePlaceID: resource,
                place: nil,
                category: category,
                distanceHint: nil
            )
        }
    }

    private static func fetchPlaceDetails(
        placeResourceName: String,
        fallbackName: String,
        fallbackSubtitle: String,
        languageCode: String,
        apiKey: String
    ) async throws -> Place {
        let token = session.currentToken
        var components = URLComponents()
        components.scheme = "https"
        components.host = "places.googleapis.com"
        components.path = "/v1/\(placeResourceName)"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "languageCode", value: languageCode),
        ]
        if let token {
            queryItems.append(URLQueryItem(name: "sessionToken", value: token))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw GoogleAPIError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        GoogleMapsREST.applyAPIKeyHeaders(
            to: &request,
            apiKey: apiKey,
            fieldMask: detailsFieldMask
        )

        let (data, _) = try await GoogleAPIHTTP.data(for: request, api: .placesDetails)

        let details = try JSONDecoder().decode(PlaceDetailsResponse.self, from: data)
        guard let lat = details.location?.latitude,
              let lon = details.location?.longitude,
              abs(lat) > 0.000_001 || abs(lon) > 0.000_001
        else {
            throw GoogleAPIError.invalidResponse
        }
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
        let types: [String]?
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
        let types: [String]?
        let primaryType: String?
    }

    private struct LatLng: Decodable {
        let latitude: Double?
        let longitude: Double?
    }
}
