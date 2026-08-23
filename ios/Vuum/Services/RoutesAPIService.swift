import Foundation

/// Google Routes API (`computeRoutes`) over HTTPS — no SPM package required.
///
/// Without `VUUM_GOOGLE_MAPS_API_KEY`, callers get `nil` and should keep using
/// `TripGeo` local polylines so the app still runs.
enum RoutesAPIService {
    struct ComputedRoute: Equatable {
        let points: [GeoPoint]
        let distanceMeters: Int
        let durationSeconds: Int
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
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
                alternates: alts
            )
        } catch {
            #if DEBUG
            print("[Vuum] RoutesAPIService error: \(error.localizedDescription)")
            #endif
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
        guard let poly = (route["polyline"] as? [String: Any])?["encodedPolyline"] as? String else {
            return nil
        }
        let points = decodePolyline(poly)
        guard points.count >= 2 else { return nil }
        return ComputedRoute(
            points: points,
            distanceMeters: distance,
            durationSeconds: durationSeconds,
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
