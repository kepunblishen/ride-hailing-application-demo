import Foundation

/// Local zone catalog (airport / downtown / demand) driving product availability and surcharge copy.
enum ServiceZoneCatalog {
    /// City-wide defaults when no special geofence matches.
    static let cityWideServices: Set<String> = [
        ServiceProductID.vuum,
        ServiceProductID.comfort,
        ServiceProductID.xxl,
        ServiceProductID.executive,
        ServiceProductID.twoWheels,
        ServiceProductID.courier,
        ServiceProductID.hourly,
        ServiceProductID.group,
        ServiceProductID.reserve,
        ServiceProductID.ride,
    ]

    static let airportExtraServices: Set<String> = [
        ServiceProductID.airport,
    ]

    static var allZones: [ServiceZone] {
        drcZones + kenyaZones
    }

    static func zones(for market: AppLocale.Market) -> [ServiceZone] {
        switch market {
        case .kenya:
            return kenyaZones
        case .drc, .both:
            return drcZones
        }
    }

    // MARK: - Resolve

    static func resolve(
        at coordinate: GeoPoint,
        market: AppLocale.Market,
        accountType: RiderAccountType = .personal,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ZoneResolution {
        let cityId = nearestCityId(to: coordinate, market: market)
        let matches = zones(for: market)
            .filter { TripGeo.contains(coordinate, in: $0.geofence) }
            .sorted { $0.priority > $1.priority }

        let primary = matches.first
        var allowed = cityDefaults(cityId: cityId, market: market)

        for zone in matches.reversed() {
            if let override = zone.allowedServiceIDs {
                allowed = override
            }
            allowed.subtract(zone.deniedServiceIDs)
            if zone.kind == .airport {
                allowed.formUnion(airportExtraServices)
            }
        }

        if accountType == .corporate {
            allowed.insert(ServiceProductID.executive)
            allowed.insert(ServiceProductID.hourly)
        }

        let isAirport = matches.contains(where: { $0.kind == .airport })
            || primary?.kind == .airport

        let surge = surgeState(
            zones: matches,
            isAirport: isAirport,
            now: now,
            calendar: calendar
        )

        let message = surchargeMessage(for: matches, surge: surge)

        return ZoneResolution(
            matchingZones: matches,
            primaryZone: primary,
            cityId: cityId,
            availableServiceIDs: allowed,
            surchargeMessage: message,
            surgeMultiplier: surge.multiplier,
            surgeLabel: surge.label,
            isAirportArea: isAirport
        )
    }

    static func resolve(
        place: Place,
        market: AppLocale.Market,
        accountType: RiderAccountType = .personal,
        now: Date = Date()
    ) -> ZoneResolution {
        resolve(at: place.coordinate, market: market, accountType: accountType, now: now)
    }

    static func isAirportPlace(_ place: Place?) -> Bool {
        guard let place else { return false }
        let blob = "\(place.name) \(place.subtitle) \(place.id)".lowercased()
        if blob.contains("airport") || blob.contains("aéroport") || blob.contains("aeroport")
            || blob.contains("jkia") || blob.contains("luano") || blob.contains("wilson") {
            return true
        }
        return allZones.contains {
            $0.kind == .airport && TripGeo.contains(place.coordinate, in: $0.geofence)
        }
    }

    static func isAirportTrip(pickup: Place, dropoff: Place?) -> Bool {
        isAirportPlace(pickup) || isAirportPlace(dropoff)
    }

    // MARK: - Cities

    private static func nearestCityId(to point: GeoPoint, market: AppLocale.Market) -> String {
        let candidates: [(id: String, center: GeoPoint)]
        switch market {
        case .kenya:
            candidates = [("nairobi", GeoPoint(latitude: -1.2864, longitude: 36.8172))]
        case .drc, .both:
            candidates = [
                ("lubumbashi", GeoPoint(latitude: -11.6644, longitude: 27.4794)),
                ("kolwezi", GeoPoint(latitude: -10.7148, longitude: 25.4667)),
            ]
        }
        return candidates.min {
            TripGeo.distanceMeters(from: point, to: $0.center)
                < TripGeo.distanceMeters(from: point, to: $1.center)
        }?.id ?? candidates[0].id
    }

    private static func cityDefaults(cityId: String, market: AppLocale.Market) -> Set<String> {
        var base = cityWideServices
        switch cityId {
        case "kolwezi":
            // Smaller fleet presentation — no airport transfer product city-wide.
            base.remove(ServiceProductID.airport)
            base.remove(ServiceProductID.hourly)
            base.remove(ServiceProductID.group)
        default:
            break
        }
        _ = market
        return base
    }

    // MARK: - Surge / messaging

    private static func surgeState(
        zones: [ServiceZone],
        isAirport: Bool,
        now: Date,
        calendar: Calendar
    ) -> SurgeState {
        let hour = calendar.component(.hour, from: now)
        let isPeak = (hour >= 7 && hour < 9) || (hour >= 17 && hour < 20)
        let midday = hour >= 11 && hour < 14

        let zoneBase = zones.map(\.surgeMultiplierBase).max() ?? 1.0
        var multiplier = max(zoneBase, 1.0)
        var label = ""
        var zoneId = zones.first?.id ?? ""

        if isAirport && isPeak {
            multiplier = max(multiplier, 1.5)
            label = "High demand"
            zoneId = zones.first(where: { $0.kind == .airport })?.id ?? "airport-peak"
        } else if isAirport {
            multiplier = max(multiplier, 1.3)
            label = zones.first(where: { $0.kind == .airport })?.surchargeLabel.isEmpty == false
                ? "Airport area"
                : "High demand"
            zoneId = zones.first(where: { $0.kind == .airport })?.id ?? "airport"
        } else if zones.contains(where: { $0.kind == .highDemand }) {
            multiplier = max(multiplier, isPeak ? 1.35 : 1.2)
            label = "High demand"
            zoneId = zones.first(where: { $0.kind == .highDemand })?.id ?? zoneId
        } else if zones.contains(where: { $0.kind == .downtown }) && (isPeak || midday) {
            multiplier = max(multiplier, isPeak ? 1.25 : 1.15)
            label = "Busy area"
            zoneId = zones.first(where: { $0.kind == .downtown })?.id ?? zoneId
        } else if isPeak {
            multiplier = max(multiplier, 1.25)
            label = "High demand"
            zoneId = "city-peak"
        } else if midday {
            multiplier = max(multiplier, 1.15)
            label = "High demand"
            zoneId = "midday"
        } else if multiplier > 1.001 {
            label = zones.first?.surchargeLabel.isEmpty == false
                ? zones.first!.kind.displayTitle
                : "High demand"
        }

        if multiplier <= 1.001 {
            return .inactive
        }
        return SurgeState(multiplier: multiplier, label: label, zoneId: zoneId)
    }

    private static func surchargeMessage(for zones: [ServiceZone], surge: SurgeState) -> String? {
        if let airport = zones.first(where: { $0.kind == .airport }) {
            let feeNote = airport.surchargeLabel
            if surge.isActive {
                return feeNote.isEmpty
                    ? "Airport area · fares are higher right now"
                    : "\(feeNote) · fares are higher right now"
            }
            return feeNote.isEmpty ? "Airport area · terminal pickup available" : feeNote
        }
        if let demand = zones.first(where: { $0.kind == .highDemand || $0.kind == .downtown }),
           surge.isActive {
            return demand.surchargeLabel.isEmpty
                ? "\(demand.kind.displayTitle) · higher fares may apply"
                : demand.surchargeLabel
        }
        if surge.isActive {
            return surge.label.isEmpty ? "Higher fares in this area right now" : "\(surge.label) · higher fares may apply"
        }
        return nil
    }

    // MARK: - DRC catalog

    private static let drcZones: [ServiceZone] = [
        ServiceZone(
            id: "lub-airport",
            name: "Luano International Airport",
            kind: .airport,
            market: .drc,
            cityId: "lubumbashi",
            geofence: .circle(
                center: GeoPoint(latitude: -11.5913, longitude: 27.5308),
                radiusMeters: 2_800
            ),
            allowedServiceIDs: [
                ServiceProductID.vuum,
                ServiceProductID.comfort,
                ServiceProductID.xxl,
                ServiceProductID.executive,
                ServiceProductID.airport,
                ServiceProductID.courier,
                ServiceProductID.reserve,
                ServiceProductID.ride,
            ],
            deniedServiceIDs: [ServiceProductID.twoWheels, ServiceProductID.group],
            surgeMultiplierBase: 1.25,
            surchargeLabel: "Airport pickup · luggage-friendly cars",
            priority: 40
        ),
        ServiceZone(
            id: "lub-downtown",
            name: "Lubumbashi Centre",
            kind: .downtown,
            market: .drc,
            cityId: "lubumbashi",
            geofence: .circle(
                center: GeoPoint(latitude: -11.6644, longitude: 27.4794),
                radiusMeters: 1_800
            ),
            allowedServiceIDs: nil,
            deniedServiceIDs: [],
            surgeMultiplierBase: 1.1,
            surchargeLabel: "Busy downtown · wait times may be longer",
            priority: 20
        ),
        ServiceZone(
            id: "lub-kenya-market-demand",
            name: "Kenya Market",
            kind: .highDemand,
            market: .drc,
            cityId: "lubumbashi",
            geofence: .circle(
                center: GeoPoint(latitude: -11.6688, longitude: 27.4751),
                radiusMeters: 900
            ),
            allowedServiceIDs: nil,
            deniedServiceIDs: [ServiceProductID.hourly],
            surgeMultiplierBase: 1.2,
            surchargeLabel: "High demand near Kenya Market",
            priority: 30
        ),
        ServiceZone(
            id: "lub-golf-premium",
            name: "Golf / Karavia",
            kind: .premium,
            market: .drc,
            cityId: "lubumbashi",
            geofence: .circle(
                center: GeoPoint(latitude: -11.6402, longitude: 27.4588),
                radiusMeters: 1_500
            ),
            allowedServiceIDs: nil,
            deniedServiceIDs: [ServiceProductID.twoWheels],
            surgeMultiplierBase: 1.05,
            surchargeLabel: "Premium area · Comfort and Executive recommended",
            priority: 15
        ),
        ServiceZone(
            id: "kwz-center",
            name: "Kolwezi Centre",
            kind: .downtown,
            market: .drc,
            cityId: "kolwezi",
            geofence: .circle(
                center: GeoPoint(latitude: -10.7148, longitude: 25.4667),
                radiusMeters: 2_200
            ),
            allowedServiceIDs: [
                ServiceProductID.vuum,
                ServiceProductID.comfort,
                ServiceProductID.xxl,
                ServiceProductID.executive,
                ServiceProductID.courier,
                ServiceProductID.reserve,
                ServiceProductID.ride,
                ServiceProductID.twoWheels,
            ],
            deniedServiceIDs: [ServiceProductID.airport, ServiceProductID.hourly, ServiceProductID.group],
            surgeMultiplierBase: 1.08,
            surchargeLabel: "Kolwezi centre",
            priority: 20
        ),
    ]

    // MARK: - Kenya catalog

    private static let kenyaZones: [ServiceZone] = [
        ServiceZone(
            id: "nbo-jkia-zone",
            name: "Jomo Kenyatta International Airport",
            kind: .airport,
            market: .kenya,
            cityId: "nairobi",
            geofence: .circle(
                center: GeoPoint(latitude: -1.3192, longitude: 36.9278),
                radiusMeters: 3_200
            ),
            allowedServiceIDs: [
                ServiceProductID.vuum,
                ServiceProductID.comfort,
                ServiceProductID.xxl,
                ServiceProductID.executive,
                ServiceProductID.airport,
                ServiceProductID.courier,
                ServiceProductID.reserve,
                ServiceProductID.ride,
            ],
            deniedServiceIDs: [ServiceProductID.twoWheels, ServiceProductID.group],
            surgeMultiplierBase: 1.3,
            surchargeLabel: "Airport area · terminal pickup available",
            priority: 40
        ),
        ServiceZone(
            id: "nbo-wilson-zone",
            name: "Wilson Airport",
            kind: .airport,
            market: .kenya,
            cityId: "nairobi",
            geofence: .circle(
                center: GeoPoint(latitude: -1.3217, longitude: 36.8148),
                radiusMeters: 1_600
            ),
            allowedServiceIDs: [
                ServiceProductID.vuum,
                ServiceProductID.comfort,
                ServiceProductID.xxl,
                ServiceProductID.executive,
                ServiceProductID.airport,
                ServiceProductID.reserve,
                ServiceProductID.ride,
            ],
            deniedServiceIDs: [ServiceProductID.twoWheels],
            surgeMultiplierBase: 1.2,
            surchargeLabel: "Wilson Airport · transfer cars available",
            priority: 40
        ),
        ServiceZone(
            id: "nbo-cbd-downtown",
            name: "Nairobi CBD",
            kind: .downtown,
            market: .kenya,
            cityId: "nairobi",
            geofence: .circle(
                center: GeoPoint(latitude: -1.2833, longitude: 36.8167),
                radiusMeters: 1_600
            ),
            allowedServiceIDs: nil,
            deniedServiceIDs: [],
            surgeMultiplierBase: 1.12,
            surchargeLabel: "Busy CBD · wait times may be longer",
            priority: 20
        ),
        ServiceZone(
            id: "nbo-westlands-demand",
            name: "Westlands",
            kind: .highDemand,
            market: .kenya,
            cityId: "nairobi",
            geofence: .circle(
                center: GeoPoint(latitude: -1.2670, longitude: 36.8110),
                radiusMeters: 1_400
            ),
            allowedServiceIDs: nil,
            deniedServiceIDs: [],
            surgeMultiplierBase: 1.18,
            surchargeLabel: "High demand in Westlands",
            priority: 30
        ),
    ]
}
