import CoreLocation
import Foundation

/// Reverse-geocodes a GPS fix into pickup labels.
///
/// Order: Google Geocoding API (when `MapBootstrap` has a key) → `CLGeocoder` →
/// coordinate fallback so the rider always sees a usable pickup name.
///
/// **"Current location"** is reserved for an unresolved GPS pickup (`id == "current"`)
/// before a street/place label arrives — never for market catalog centers.
enum ReverseGeocodingService {
    /// Temporary primary line while GPS pickup awaits reverse geocode.
    static let unresolvedPickupName = "Current location"

    struct AddressLabel: Equatable {
        /// Primary pickup line (street / place).
        let name: String
        /// Secondary line (locality or coordinate fallback).
        let subtitle: String
    }

    static func isUnresolvedPickupName(_ name: String) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(unresolvedPickupName) == .orderedSame
    }

    /// Resolves `location` to display labels. Never throws to callers.
    static func reverseGeocode(_ location: CLLocation) async -> AddressLabel {
        if let cached = MapsRequestCache.cachedGeocode(for: location.coordinate) {
            return cached
        }
        MapBootstrap.configureIfNeeded()
        if MapBootstrap.hasAPIKey, let key = MapBootstrap.resolvedAPIKey() {
            if let google = await googleReverseGeocode(location, apiKey: key) {
                MapsRequestCache.storeGeocode(google, for: location.coordinate)
                return google
            }
        }
        if let apple = await appleReverseGeocode(location) {
            MapsRequestCache.storeGeocode(apple, for: location.coordinate)
            return apple
        }
        return coordinateFallback(location)
    }

    static func coordinateFallback(_ location: CLLocation) -> AddressLabel {
        AddressLabel(
            name: unresolvedPickupName,
            subtitle: coordinateSubtitle(location)
        )
    }

    static func coordinateSubtitle(_ location: CLLocation) -> String {
        String(
            format: "%.5f, %.5f",
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    // MARK: - Google

    private static func googleReverseGeocode(_ location: CLLocation, apiKey: String) async -> AddressLabel? {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")
        components?.queryItems = [
            URLQueryItem(
                name: "latlng",
                value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            ),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "language", value: preferredLanguageCode),
            URLQueryItem(name: "result_type", value: "street_address|route|premise|neighborhood|sublocality|locality"),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        GoogleMapsREST.applyBundleIdentifier(to: &request)

        do {
            let (data, _) = try await GoogleAPIHTTP.data(for: request, api: .geocode)
            let decoded = try JSONDecoder().decode(GoogleGeocodeResponse.self, from: data)
            if let statusError = GoogleAPIError.mapGoogleStatus(decoded.status) {
                await GoogleMapsDiagnostics.shared.noteError(statusError, api: .geocode)
                return nil
            }
            guard decoded.status == "OK", let first = decoded.results.first else { return nil }
            return label(from: first, location: location)
        } catch {
            #if DEBUG
            print("[Vuum] Google reverse geocode failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private static func label(from result: GoogleGeocodeResult, location: CLLocation) -> AddressLabel {
        let comps = result.addressComponents ?? []
        let streetNumber = component("street_number", in: comps)
        let route = component("route", in: comps)
        let premise = component("premise", in: comps)
        let neighborhood = component("neighborhood", in: comps)
            ?? component("sublocality", in: comps)
            ?? component("sublocality_level_1", in: comps)
        let locality = component("locality", in: comps)
            ?? component("administrative_area_level_2", in: comps)
        let admin = component("administrative_area_level_1", in: comps)

        let streetLine: String? = {
            if let streetNumber, let route {
                return "\(streetNumber) \(route)"
            }
            if let route { return route }
            if let premise { return premise }
            if let neighborhood { return neighborhood }
            if let locality { return locality }
            return nil
        }()

        let name: String
        if let streetLine, !streetLine.isEmpty {
            name = streetLine
        } else if let formatted = result.formattedAddress?.split(separator: ",").first.map(String.init) {
            let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
            name = trimmed.isEmpty ? unresolvedPickupName : trimmed
        } else {
            name = unresolvedPickupName
        }

        let subtitleParts = [locality, admin]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0.caseInsensitiveCompare(name) != .orderedSame }

        let subtitle: String
        if !subtitleParts.isEmpty {
            subtitle = subtitleParts.joined(separator: ", ")
        } else if let formatted = result.formattedAddress, !isUnresolvedPickupName(name) {
            let rest = formatted
                .split(separator: ",")
                .dropFirst()
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            subtitle = rest.isEmpty
                ? coordinateSubtitle(location)
                : rest.prefix(2).joined(separator: ", ")
        } else {
            subtitle = coordinateSubtitle(location)
        }

        return AddressLabel(name: name, subtitle: subtitle)
    }

    private static func component(_ type: String, in comps: [GoogleAddressComponent]) -> String? {
        comps.first(where: { $0.types.contains(type) })?.longName
    }

    // MARK: - Apple

    private static func appleReverseGeocode(_ location: CLLocation) async -> AddressLabel? {
        await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    #if DEBUG
                    print("[Vuum] CLGeocoder failed: \(error.localizedDescription)")
                    #endif
                    continuation.resume(returning: nil)
                    return
                }
                guard let place = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: label(from: place, location: location))
            }
        }
    }

    private static func label(from placemark: CLPlacemark, location: CLLocation) -> AddressLabel {
        let streetNumber = placemark.subThoroughfare
        let route = placemark.thoroughfare
        let streetLine: String? = {
            if let streetNumber, let route {
                return "\(streetNumber) \(route)"
            }
            return route ?? placemark.name
        }()

        let rawName = (streetLine?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        }
        // Avoid promoting Apple's generic "Current Location" placemark name as a final label.
        let name: String = {
            guard let rawName else { return unresolvedPickupName }
            if isUnresolvedPickupName(rawName) { return unresolvedPickupName }
            return rawName
        }()

        let subtitleParts = [
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && $0.caseInsensitiveCompare(name) != .orderedSame }

        let subtitle: String
        if subtitleParts.isEmpty {
            subtitle = coordinateSubtitle(location)
        } else {
            subtitle = Array(subtitleParts.prefix(2)).joined(separator: ", ")
        }

        return AddressLabel(name: name, subtitle: subtitle)
    }

    private static var preferredLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
}

// MARK: - Google JSON

private struct GoogleGeocodeResponse: Decodable {
    let status: String
    let results: [GoogleGeocodeResult]
}

private struct GoogleGeocodeResult: Decodable {
    let formattedAddress: String?
    let addressComponents: [GoogleAddressComponent]?

    enum CodingKeys: String, CodingKey {
        case formattedAddress = "formatted_address"
        case addressComponents = "address_components"
    }
}

private struct GoogleAddressComponent: Decodable {
    let longName: String
    let types: [String]

    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case types
    }
}
