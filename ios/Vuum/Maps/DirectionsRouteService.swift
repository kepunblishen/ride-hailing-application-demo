import Foundation

/// Fetches road-following polylines from Google Directions when an API key is present.
/// Falls back silently; callers should use `RouteEngine` which always returns a usable path.
enum DirectionsRouteService {
    struct LegResult: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        var durationSeconds: TimeInterval
    }

    /// Returns `nil` when the key is missing, the request fails, or the response has no route.
    static func fetchRoute(
        origin: GeoPoint,
        destination: GeoPoint,
        waypoints: [GeoPoint] = []
    ) async -> LegResult? {
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey, let key = MapBootstrap.resolvedAPIKey() else { return nil }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "key", value: key),
        ]
        if !waypoints.isEmpty {
            let joined = waypoints
                .map { "\($0.latitude),\($0.longitude)" }
                .joined(separator: "|")
            query.append(URLQueryItem(name: "waypoints", value: joined))
        }
        components?.queryItems = query
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)
            guard decoded.status == "OK",
                  let route = decoded.routes.first,
                  let points = EncodedPolyline.decode(route.overview_polyline.points),
                  points.count >= 2
            else {
                return nil
            }
            let distance = route.legs.reduce(0.0) { $0 + Double($1.distance.value) }
            let duration = route.legs.reduce(0.0) { $0 + Double($1.duration.value) }
            return LegResult(
                coordinates: points,
                distanceMeters: distance > 0 ? distance : TripGeo.pathLengthMeters(points),
                durationSeconds: duration
            )
        } catch {
            #if DEBUG
            print("[Vuum] Directions request failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}

// MARK: - JSON

private struct DirectionsResponse: Decodable {
    var status: String
    var routes: [DirectionsRoute]
}

private struct DirectionsRoute: Decodable {
    var overview_polyline: OverviewPolyline
    var legs: [DirectionsLeg]
}

private struct OverviewPolyline: Decodable {
    var points: String
}

private struct DirectionsLeg: Decodable {
    var distance: TextValue
    var duration: TextValue
}

private struct TextValue: Decodable {
    var value: Int
}

// MARK: - Encoded polyline

enum EncodedPolyline {
    static func decode(_ encoded: String) -> [GeoPoint]? {
        var coordinates: [GeoPoint] = []
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            var result = 0
            var shift = 0
            var byte: Int
            repeat {
                guard index < encoded.endIndex else { return nil }
                byte = Int(encoded[index].utf16.first ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            let deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lat += deltaLat

            result = 0
            shift = 0
            repeat {
                guard index < encoded.endIndex else { return nil }
                byte = Int(encoded[index].utf16.first ?? 0) - 63
                index = encoded.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20
            let deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            lng += deltaLng

            coordinates.append(
                GeoPoint(
                    latitude: Double(lat) / 1e5,
                    longitude: Double(lng) / 1e5
                )
            )
        }
        return coordinates.isEmpty ? nil : coordinates
    }
}
