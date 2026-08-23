import Foundation

/// Google Routes API (`computeRoutes`) over HTTPS — no SPM package required.
///
/// Without `VUUM_GOOGLE_MAPS_API_KEY`, callers get `nil` and should keep using
/// `TripGeo` local polylines so the app still runs.
///
/// Primary routing stack for Vuum (`GoogleRouteProvider`). Directions is fallback only.
enum RoutesAPIService {
    struct ComputedLeg: Equatable {
        let points: [GeoPoint]
        let distanceMeters: Int
        /// Traffic-aware when `routingPreference` is `TRAFFIC_AWARE`.
        let durationSeconds: Int
        let staticDurationSeconds: Int?
    }

    struct ComputedRoute: Equatable {
        let points: [GeoPoint]
        let distanceMeters: Int
        /// Traffic-aware duration (`routes.duration` under TRAFFIC_AWARE).
        let durationSeconds: Int
        /// Duration without live traffic (`routes.staticDuration`), when present.
        let staticDurationSeconds: Int?
        let legs: [ComputedLeg]
        /// Additional routes when `computeAlternativeRoutes` was requested.
        let alternates: [ComputedRoute]

        var etaMinutes: Int {
            max(1, Int(ceil(Double(durationSeconds) / 60.0)))
        }
    }

    /// Traffic-aware route from origin → optional intermediate waypoints → destination.
    static func computeRoute(
        origin: GeoPoint,
        destination: GeoPoint,
        intermediates: [GeoPoint] = [],
        alternatives: Bool = false
    ) async -> ComputedRoute? {
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey,
              let key = MapBootstrap.resolvedAPIKey(),
              MapBootstrap.isUsableAPIKey(key)
        else { return nil }

        var intermediatePayload: [[String: Any]] = []
        for point in intermediates {
            intermediatePayload.append([
                "location": [
                    "latLng": [
                        "latitude": point.latitude,
                        "longitude": point.longitude,
                    ],
                ],
            ])
        }

        var body: [String: Any] = [
            "origin": locationDict(origin),
            "destination": locationDict(destination),
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
            "computeAlternativeRoutes": alternatives,
            "languageCode": Locale.current.language.languageCode?.identifier ?? "en",
        ]
        if !intermediatePayload.isEmpty {
            body["intermediates"] = intermediatePayload
        }

        guard let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes"),
              let httpBody = try? JSONSerialization.data(withJSONObject: body)
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        GoogleMapsREST.applyAPIKeyHeaders(
            to: &request,
            apiKey: key,
            fieldMask: "routes.duration,routes.staticDuration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.duration,routes.legs.staticDuration,routes.legs.distanceMeters,routes.legs.polyline.encodedPolyline"
        )

        do {
            let (data, _) = try await GoogleAPIHTTP.data(for: request, api: .routes)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let routes = json["routes"] as? [[String: Any]],
                  let first = routes.first,
                  let computed = parseRoute(first)
            else {
                #if DEBUG
                print("[Vuum] RoutesAPIService — empty or failed response (status check / field mask).")
                #endif
                return nil
            }
            let alts = routes.dropFirst().compactMap { parseRoute($0) }
            return ComputedRoute(
                points: computed.points,
                distanceMeters: computed.distanceMeters,
                durationSeconds: computed.durationSeconds,
                staticDurationSeconds: computed.staticDurationSeconds,
                legs: computed.legs,
                alternates: alts
            )
        } catch let error as GoogleAPIError {
            await GoogleMapsDiagnostics.shared.noteError(error, api: .routes)
            return nil
        } catch {
            await GoogleMapsDiagnostics.shared.noteError(.invalidResponse, api: .routes)
            return nil
        }
    }

    private static func locationDict(_ point: GeoPoint) -> [String: Any] {
        [
            "location": [
                "latLng": [
                    "latitude": point.latitude,
                    "longitude": point.longitude,
                ],
            ],
        ]
    }

    private static func parseRoute(_ route: [String: Any]) -> ComputedRoute? {
        let distance = route["distanceMeters"] as? Int ?? 0
        let durationSeconds = parseDurationSeconds(route["duration"] as? String)
        let staticDurationSeconds: Int? = {
            let value = parseDurationSeconds(route["staticDuration"] as? String)
            return value > 0 ? value : nil
        }()
        guard let poly = (route["polyline"] as? [String: Any])?["encodedPolyline"] as? String else {
            return nil
        }
        let points = decodePolyline(poly)
        guard points.count >= 2 else { return nil }

        let legsJSON = route["legs"] as? [[String: Any]] ?? []
        let legs: [ComputedLeg] = legsJSON.compactMap { leg in
            let legDistance = leg["distanceMeters"] as? Int ?? 0
            let legDuration = parseDurationSeconds(leg["duration"] as? String)
            let legStatic: Int? = {
                let value = parseDurationSeconds(leg["staticDuration"] as? String)
                return value > 0 ? value : nil
            }()
            let legPoints: [GeoPoint]
            if let encoded = (leg["polyline"] as? [String: Any])?["encodedPolyline"] as? String {
                let decoded = decodePolyline(encoded)
                legPoints = decoded.count >= 2 ? decoded : []
            } else {
                legPoints = []
            }
            guard legDistance > 0 || legDuration > 0 || legPoints.count >= 2 else { return nil }
            return ComputedLeg(
                points: legPoints,
                distanceMeters: legDistance,
                durationSeconds: max(legDuration, 1),
                staticDurationSeconds: legStatic
            )
        }

        return ComputedRoute(
            points: points,
            distanceMeters: distance,
            durationSeconds: max(durationSeconds, 1),
            staticDurationSeconds: staticDurationSeconds,
            legs: legs,
            alternates: []
        )
    }

    /// Parses Routes API duration strings like `"1234s"`.
    private static func parseDurationSeconds(_ raw: String?) -> Int {
        guard let raw else { return 0 }
        if raw.hasSuffix("s"), let value = Int(raw.dropLast()) {
            return max(0, value)
        }
        return Int(raw) ?? 0
    }

    /// Google encoded polyline algorithm.
    static func decodePolyline(_ encoded: String) -> [GeoPoint] {
        var points: [GeoPoint] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var result = 0
            var shift = 0
            var byte: Int
            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex
            let dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += dlat

            result = 0
            shift = 0
            repeat {
                byte = Int(encoded[index].asciiValue ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index < encoded.endIndex
            let dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += dlng

            points.append(GeoPoint(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return points
    }
}
