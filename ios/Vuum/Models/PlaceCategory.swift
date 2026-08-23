import Foundation

/// Rider-facing place classification for search chrome (icons + short labels).
/// Derived from Google Place Types when present, otherwise from name/subtitle heuristics.
enum PlaceCategory: String, Equatable, Sendable, CaseIterable {
    case airport
    case hotel
    case restaurant
    case hospital
    case university
    case landmark
    case office
    case transit
    case shopping
    case industrial
    case business
    case address
    case other

    var systemImage: String {
        switch self {
        case .airport: return "airplane"
        case .hotel: return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .hospital: return "cross.case.fill"
        case .university: return "graduationcap.fill"
        case .landmark: return "building.columns.fill"
        case .office: return "building.2.fill"
        case .transit: return "tram.fill"
        case .shopping: return "bag.fill"
        case .industrial: return "hammer.fill"
        case .business: return "storefront.fill"
        case .address: return "mappin.circle.fill"
        case .other: return "mappin.and.ellipse"
        }
    }

    /// Compact label for search context line; `nil` when the icon alone is enough.
    var shortLabel: String? {
        switch self {
        case .airport: return "Airport"
        case .hotel: return "Hotel"
        case .restaurant: return "Restaurant"
        case .hospital: return "Hospital"
        case .university: return "University"
        case .landmark: return "Landmark"
        case .office: return "Office"
        case .transit: return "Transit"
        case .shopping: return "Shopping"
        case .industrial: return "Industrial"
        case .business: return "Business"
        case .address, .other: return nil
        }
    }

    /// Prefer Google `types` / `primaryType`, then local name heuristics.
    static func infer(
        googleTypes: [String]?,
        primaryType: String? = nil,
        name: String,
        subtitle: String,
        placeID: String? = nil
    ) -> PlaceCategory {
        var types = Set((googleTypes ?? []).map { normalize($0) })
        if let primaryType, !primaryType.isEmpty {
            types.insert(normalize(primaryType))
        }
        if let fromTypes = fromGoogleTypes(types) {
            return fromTypes
        }
        return fromText(name: name, subtitle: subtitle, placeID: placeID)
    }

    private static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func fromGoogleTypes(_ types: Set<String>) -> PlaceCategory? {
        if types.contains("airport") { return .airport }
        if types.contains("lodging") || types.contains("hotel") { return .hotel }
        if types.contains("restaurant")
            || types.contains("cafe")
            || types.contains("meal_takeaway")
            || types.contains("food") {
            return .restaurant
        }
        if types.contains("hospital")
            || types.contains("doctor")
            || types.contains("pharmacy") {
            return .hospital
        }
        if types.contains("university")
            || types.contains("school")
            || types.contains("secondary_school") {
            return .university
        }
        if types.contains("tourist_attraction")
            || types.contains("museum")
            || types.contains("park")
            || types.contains("church")
            || types.contains("place_of_worship") {
            return .landmark
        }
        if types.contains("local_government_office")
            || types.contains("courthouse")
            || types.contains("city_hall") {
            return .office
        }
        if types.contains("transit_station")
            || types.contains("train_station")
            || types.contains("subway_station")
            || types.contains("bus_station")
            || types.contains("light_rail_station") {
            return .transit
        }
        if types.contains("shopping_mall")
            || types.contains("supermarket")
            || types.contains("department_store")
            || types.contains("store") {
            return .shopping
        }
        if types.contains("mine") || types.contains("industrial") { return .industrial }
        if types.contains("street_address")
            || types.contains("premise")
            || types.contains("subpremise")
            || types.contains("route")
            || types.contains("geocode") {
            return .address
        }
        if types.contains("point_of_interest") || types.contains("establishment") {
            return .business
        }
        return nil
    }

    private static func fromText(name: String, subtitle: String, placeID: String?) -> PlaceCategory {
        let blob = "\(placeID ?? "") \(name) \(subtitle)".lowercased()

        if blob.contains("airport") || blob.contains("aéroport") || blob.contains("aeroport")
            || blob.contains("jkia") || blob.contains("wilson") || blob.contains("fbm") {
            return .airport
        }
        if blob.contains("hotel") || blob.contains("hôtel") || blob.contains("lodge") {
            return .hotel
        }
        if blob.contains("hospital") || blob.contains("hôpital") || blob.contains("clinic")
            || blob.contains("clinique") {
            return .hospital
        }
        if blob.contains("universit") || blob.contains("campus") || blob.contains("school")
            || blob.contains("école") || blob.contains("ecole") {
            return .university
        }
        if blob.contains("gare") || blob.contains("station") || blob.contains("terminal") {
            return .transit
        }
        if blob.contains("mall") || blob.contains("market") || blob.contains("marché")
            || blob.contains("marche") || blob.contains("supermarket") {
            return .shopping
        }
        if blob.contains("mine") || blob.contains("mining") || blob.contains("industriel") {
            return .industrial
        }
        if blob.contains("restaurant") || blob.contains("café") || blob.contains("cafe") {
            return .restaurant
        }
        if blob.contains("office") || blob.contains("bureau") || blob.contains("tower") {
            return .office
        }
        if blob.contains("museum") || blob.contains("monument") || blob.contains("park")
            || blob.contains("golf") {
            return .landmark
        }
        return .address
    }
}
