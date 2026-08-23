import Foundation

enum MockPlaces {
    /// Nairobi CBD — demo default (swap later per market).
    static let defaultPickup = Place(
        id: "pickup-default",
        name: "Current location",
        subtitle: "Kimathi Street, Nairobi",
        coordinate: GeoPoint(latitude: -1.2833, longitude: 36.8219)
    )

    static let destinations: [Place] = [
        Place(
            id: "dest-jkia",
            name: "Jomo Kenyatta International Airport",
            subtitle: "Airport North Rd",
            coordinate: GeoPoint(latitude: -1.3192, longitude: 36.9275)
        ),
        Place(
            id: "dest-westlands",
            name: "Westlands",
            subtitle: "Waiyaki Way",
            coordinate: GeoPoint(latitude: -1.2670, longitude: 36.8120)
        ),
        Place(
            id: "dest-kilimani",
            name: "Kilimani",
            subtitle: "Argwings Kodhek Rd",
            coordinate: GeoPoint(latitude: -1.2921, longitude: 36.7830)
        ),
        Place(
            id: "dest-lavington",
            name: "Lavington",
            subtitle: "James Gichuru Rd",
            coordinate: GeoPoint(latitude: -1.2775, longitude: 36.7685)
        ),
    ]

    static func nearbyDriverSeed(from pickup: Place) -> GeoPoint {
        GeoPoint(
            latitude: pickup.coordinate.latitude + 0.008,
            longitude: pickup.coordinate.longitude - 0.006
        )
    }
}

enum MockDrivers {
    private static let pool: [DriverProfile] = [
        DriverProfile(id: "d1", name: "Amina K.", rating: 4.92, vehicle: "Toyota Axio", plate: "KDG 482A", etaMinutes: 4),
        DriverProfile(id: "d2", name: "Brian O.", rating: 4.87, vehicle: "Mazda Demio", plate: "KCR 901B", etaMinutes: 6),
        DriverProfile(id: "d3", name: "Faith W.", rating: 4.95, vehicle: "Honda Fit", plate: "KDA 215C", etaMinutes: 3),
    ]

    static func random() -> DriverProfile {
        pool.randomElement() ?? pool[0]
    }
}

enum MockFares {
    static func tiers(from _: Place, to _: Place) -> [RideTier] {
        [
            RideTier(
                id: "vuum-go",
                name: "Vuum Go",
                detail: "Everyday rides",
                capacity: 4,
                etaMinutes: 4,
                priceEstimate: "KSh 420–480",
                systemImage: "car.fill"
            ),
            RideTier(
                id: "vuum-xl",
                name: "Vuum XL",
                detail: "Extra space",
                capacity: 6,
                etaMinutes: 7,
                priceEstimate: "KSh 620–710",
                systemImage: "car.side.fill"
            ),
            RideTier(
                id: "vuum-black",
                name: "Vuum Black",
                detail: "Premium comfort",
                capacity: 4,
                etaMinutes: 9,
                priceEstimate: "KSh 980–1,150",
                systemImage: "car.circle.fill"
            ),
        ]
    }
}
