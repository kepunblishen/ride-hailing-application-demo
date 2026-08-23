import CoreLocation
import Foundation

enum TripPhase: String, Equatable {
    case idle
    case selectingDestination
    case choosingRide
    case searching
    case assigned
    case inTrip
    case completed
}

struct GeoPoint: Equatable, Hashable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct Place: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var subtitle: String
    var coordinate: GeoPoint
}

struct RideTier: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var detail: String
    var capacity: Int
    var etaMinutes: Int
    var priceEstimate: String
    var systemImage: String
}

struct DriverProfile: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var rating: Double
    var vehicle: String
    var plate: String
    var etaMinutes: Int
}

struct ActiveTrip: Equatable {
    var pickup: Place
    var dropoff: Place
    var tier: RideTier
    var driver: DriverProfile
    var fare: String
    var driverCoordinate: GeoPoint
}
