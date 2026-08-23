import Foundation

/// Product / ride identifiers used for zone availability (tiers + home/services products).
enum ServiceProductID {
    static let vuum = "vuum"
    static let comfort = "comfort"
    static let xxl = "xxl"
    static let xl = "xl" // Home shortcut; maps to `xxl`
    static let executive = "executive"
    static let airport = "airport"
    static let twoWheels = "two-wheels"
    static let courier = "courier"
    static let hourly = "hourly"
    static let group = "group"
    static let reserve = "reserve"
    static let rental = "rental"
    static let ride = "ride"

    /// Normalizes home / shortcut IDs onto catalog tier IDs.
    static func canonical(_ id: String) -> String {
        switch id {
        case xl: return xxl
        case ride: return vuum
        default: return id
        }
    }

    static func matches(_ productID: String, allowed: Set<String>) -> Bool {
        let c = canonical(productID)
        if allowed.contains(productID) || allowed.contains(c) { return true }
        if productID == xl || productID == xxl {
            return allowed.contains(xxl) || allowed.contains(xl)
        }
        if productID == ride {
            return allowed.contains(vuum) || allowed.contains(ride)
        }
        return false
    }

    /// Vehicle-shaped SF Symbol for fare / product rows (prefer clarity over abstract badges).
    static func systemImage(forProductID id: String) -> String {
        switch canonical(id) {
        case vuum, ride:
            return "car.fill"
        case comfort:
            return "car.side.fill"
        case xxl, xl:
            return "car.2.fill"
        case executive:
            return "car.side.fill"
        case airport:
            return "airplane"
        case twoWheels:
            return "bicycle"
        case courier:
            return "shippingbox.fill"
        case hourly:
            return "clock.fill"
        case group:
            return "person.3.fill"
        case reserve:
            return "calendar"
        case rental:
            return "key.fill"
        default:
            return VehicleClass.resolving(tierID: id).systemImage
        }
    }
}

enum ServiceZoneKind: String, Codable, CaseIterable, Identifiable {
    case cityDefault
    case downtown
    case airport
    case highDemand
    case premium

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .cityDefault: return "City"
        case .downtown: return "Downtown"
        case .airport: return "Airport"
        case .highDemand: return "High demand"
        case .premium: return "Premium"
        }
    }
}

enum ZoneGeofence: Equatable, Hashable {
    case circle(center: GeoPoint, radiusMeters: Double)
    case polygon([GeoPoint])
}

/// Local operating zone (airport, downtown, demand) with product availability rules.
struct ServiceZone: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var kind: ServiceZoneKind
    /// `.kenya` or `.drc` (`.both` not used on zone rows).
    var market: AppLocale.Market
    /// e.g. `lubumbashi`, `kolwezi`, `nairobi`
    var cityId: String
    var geofence: ZoneGeofence
    /// When non-nil, only these services are offered (before denies / account boosts).
    var allowedServiceIDs: Set<String>?
    var deniedServiceIDs: Set<String>
    /// Baseline surge when inside this zone (time-of-day may raise further).
    var surgeMultiplierBase: Double
    /// Rider-facing line when this zone drives pricing (no “demo” wording).
    var surchargeLabel: String
    /// Higher wins when geofences overlap.
    var priority: Int
}

/// Resolved pickup context for availability + messaging.
struct ZoneResolution: Equatable {
    var matchingZones: [ServiceZone]
    var primaryZone: ServiceZone?
    var cityId: String
    var availableServiceIDs: Set<String>
    var surchargeMessage: String?
    var surgeMultiplier: Double
    var surgeLabel: String
    var isAirportArea: Bool

    var isOutsideServiceArea: Bool {
        availableServiceIDs.isEmpty
    }

    func allows(serviceID: String) -> Bool {
        ServiceProductID.matches(serviceID, allowed: availableServiceIDs)
    }

    static let empty = ZoneResolution(
        matchingZones: [],
        primaryZone: nil,
        cityId: "",
        availableServiceIDs: [],
        surchargeMessage: nil,
        surgeMultiplier: 1.0,
        surgeLabel: "",
        isAirportArea: false
    )
}

enum RiderAccountType: String, Equatable {
    case personal
    case corporate
}
