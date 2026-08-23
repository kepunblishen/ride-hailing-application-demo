import Foundation

/// Central Google → VUUM error map. Rider copy via `L10n`; never expose raw Google JSON.
enum GoogleAPIError: Error, Equatable, Sendable {
    case missingAPIKey
    case httpStatus(Int)
    case googleStatus(String)
    case network(URLError.Code)
    case invalidResponse
    case cancelled

    /// Short code for diagnostics / DEBUG logs (never includes API keys).
    var diagnosticCode: String {
        switch self {
        case .missingAPIKey: return "MISSING_KEY"
        case .httpStatus(let code): return "HTTP_\(code)"
        case .googleStatus(let status): return status.uppercased()
        case .network(let code): return "URL_\(code.rawValue)"
        case .invalidResponse: return "INVALID_RESPONSE"
        case .cancelled: return "CANCELLED"
        }
    }

    /// Transient failures only — invalid key / 403 / malformed requests must not retry.
    var isRetryable: Bool {
        switch self {
        case .missingAPIKey, .invalidResponse, .cancelled:
            return false
        case .httpStatus(let code):
            return Self.retryableHTTPStatuses.contains(code)
        case .googleStatus(let status):
            return Self.retryableGoogleStatuses.contains(status.uppercased())
        case .network(let code):
            return Self.retryableURLCodes.contains(code)
        }
    }

    /// Rider-facing string (localized). Never mentions Google / HTTP / keys.
    var riderMessage: String {
        L10n.t(riderMessageKey)
    }

    var riderMessageKey: String {
        switch self {
        case .missingAPIKey:
            return "maps.error.unavailable"
        case .httpStatus(let code):
            if code == 401 || code == 403 { return "maps.error.unavailable" }
            if code == 429 { return "maps.error.busy" }
            if (500...599).contains(code) { return "maps.error.temporary" }
            if code == 408 { return "maps.error.temporary" }
            return "maps.error.generic"
        case .googleStatus(let status):
            switch status.uppercased() {
            case "REQUEST_DENIED", "INVALID_REQUEST":
                return "maps.error.unavailable"
            case "OVER_QUERY_LIMIT", "OVER_DAILY_LIMIT", "RESOURCE_EXHAUSTED":
                return "maps.error.busy"
            case "UNKNOWN_ERROR":
                return "maps.error.temporary"
            case "ZERO_RESULTS", "NOT_FOUND":
                return "maps.error.no_route"
            default:
                return "maps.error.generic"
            }
        case .network(let code):
            if code == .timedOut { return "maps.error.temporary" }
            return "maps.error.network"
        case .invalidResponse:
            return "maps.error.generic"
        case .cancelled:
            return "maps.error.generic"
        }
    }

    static func mapHTTP(_ statusCode: Int) -> GoogleAPIError {
        .httpStatus(statusCode)
    }

    static func mapURLError(_ error: URLError) -> GoogleAPIError {
        if error.code == .cancelled { return .cancelled }
        return .network(error.code)
    }

    /// Maps legacy Directions / Geocoding `status` field (e.g. `REQUEST_DENIED`).
    static func mapGoogleStatus(_ status: String) -> GoogleAPIError? {
        let upper = status.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !upper.isEmpty, upper != "OK" else { return nil }
        return .googleStatus(upper)
    }

    private static let retryableHTTPStatuses: Set<Int> = [408, 429, 500, 502, 503, 504]

    private static let retryableGoogleStatuses: Set<String> = [
        "OVER_QUERY_LIMIT",
        "OVER_DAILY_LIMIT",
        "RESOURCE_EXHAUSTED",
        "UNKNOWN_ERROR",
    ]

    private static let retryableURLCodes: Set<URLError.Code> = [
        .timedOut,
        .networkConnectionLost,
        .notConnectedToInternet,
        .cannotConnectToHost,
        .cannotFindHost,
        .dnsLookupFailed,
        .internationalRoamingOff,
        .dataNotAllowed,
    ]
}

enum GoogleAPIKind: String, Sendable {
    case placesAutocomplete = "places.autocomplete"
    case placesDetails = "places.details"
    case routes = "routes.compute"
    case directions = "directions"
    case geocode = "geocode"
}
