import Foundation

/// Fetches road-following polylines from Google Directions when an API key is present.
///
/// **Fallback only** — `GoogleRouteProvider` / `RouteEngine` try Routes API first.
/// Falls back silently; callers should use `RouteEngine` which always returns a usable path.
enum DirectionsRouteService {
    struct LegSegment: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        /// Preferred duration (traffic when `duration_in_traffic` present).
        var durationSeconds: TimeInterval
        var staticDurationSeconds: TimeInterval?
        var trafficDurationSeconds: TimeInterval?
    }

    struct LegResult: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        /// Preferred duration (sum of traffic-aware leg durations when available).
        var durationSeconds: TimeInterval
        var staticDurationSeconds: TimeInterval?
        var trafficDurationSeconds: TimeInterval?
        var legs: [LegSegment]
    }

    /// Returns `nil` when the key is missing, the request fails, or the response has no route.
    /// Uses `departure_time=now` so legs can include traffic-aware `duration_in_traffic` when available.
    static func fetchRoute(
        origin: GeoPoint,
        destination: GeoPoint,
        waypoints: [GeoPoint] = []
    ) async -> LegResult? {
        MapBootstrap.configureIfNeeded()
        guard MapBootstrap.hasAPIKey,
              let key = MapBootstrap.resolvedAPIKey(),
              MapBootstrap.isUsableAPIKey(key)
        else { return nil }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/directions/json")
        var query: [URLQueryItem] = [
            URLQueryItem(name: "origin", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "destination", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: "driving"),
            URLQueryItem(name: "departure_time", value: "now"),
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

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        GoogleMapsREST.applyBundleIdentifier(to: &request)

        do {
            let (data, _) = try await GoogleAPIHTTP.data(for: request, api: .directions)
            let decoded = try JSONDecoder().decode(DirectionsResponse.self, from: data)
            if let statusError = GoogleAPIError.mapGoogleStatus(decoded.status) {
                await GoogleMapsDiagnostics.shared.noteError(statusError, api: .directions)
                return nil
            }
            guard decoded.status == "OK",
                  let route = decoded.routes.first,
                  let points = EncodedPolyline.decode(route.overview_polyline.points),
                  points.count >= 2
            else {
                return nil
            }

            var segments: [LegSegment] = []
            var staticTotal: TimeInterval = 0
            var trafficTotal: TimeInterval = 0
            var preferredTotal: TimeInterval = 0
            var hasTraffic = false

            for leg in route.legs {
                let staticSec = TimeInterval(leg.duration.value)
                let trafficSec = leg.duration_in_traffic.map { TimeInterval($0.value) }
                let preferred = trafficSec ?? staticSec
                if trafficSec != nil { hasTraffic = true }
                staticTotal += staticSec
                trafficTotal += trafficSec ?? staticSec
                preferredTotal += preferred

                var legCoords: [GeoPoint] = []
                for step in leg.steps ?? [] {
                    if let decodedStep = EncodedPolyline.decode(step.polyline.points) {
                        if legCoords.isEmpty {
                            legCoords.append(contentsOf: decodedStep)
                        } else if decodedStep.count > 1 {
                            legCoords.append(contentsOf: decodedStep.dropFirst())
                        }
                    }
                }

                segments.append(
                    LegSegment(
                        coordinates: legCoords,
                        distanceMeters: Double(leg.distance.value),
                        durationSeconds: preferred,
                        staticDurationSeconds: staticSec,
                        trafficDurationSeconds: trafficSec
                    )
                )
            }

            let distance = route.legs.reduce(0.0) { $0 + Double($1.distance.value) }
            return LegResult(
                coordinates: points,
                distanceMeters: distance > 0 ? distance : TripGeo.pathLengthMeters(points),
                durationSeconds: preferredTotal > 0 ? preferredTotal : trafficTotal,
                staticDurationSeconds: staticTotal > 0 ? staticTotal : nil,
                trafficDurationSeconds: hasTraffic ? trafficTotal : nil,
                legs: segments
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
    /// Present when `departure_time` was set; prefer over static `duration`.
    var duration_in_traffic: TextValue?
    var steps: [DirectionsStep]?
}

private struct DirectionsStep: Decodable {
    var polyline: OverviewPolyline
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
