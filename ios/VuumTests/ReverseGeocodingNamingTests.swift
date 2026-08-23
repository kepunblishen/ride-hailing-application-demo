import CoreLocation
import XCTest
@testable import Vuum

final class ReverseGeocodingNamingTests: XCTestCase {
    func testUnresolvedPickupNameIsStable() {
        XCTAssertEqual(ReverseGeocodingService.unresolvedPickupName, "Current location")
        XCTAssertTrue(ReverseGeocodingService.isUnresolvedPickupName("Current location"))
        XCTAssertTrue(ReverseGeocodingService.isUnresolvedPickupName("  current location  "))
        XCTAssertFalse(ReverseGeocodingService.isUnresolvedPickupName("Avenue Mobutu"))
    }

    func testCoordinateFallbackUsesUnresolvedNameAndCoords() {
        let location = CLLocation(latitude: -11.66440, longitude: 27.47940)
        let label = ReverseGeocodingService.coordinateFallback(location)
        XCTAssertEqual(label.name, ReverseGeocodingService.unresolvedPickupName)
        XCTAssertFalse(ReverseGeocodingService.isUnresolvedPickupName(label.subtitle))
        XCTAssertTrue(label.subtitle.contains("-11.66"))
        XCTAssertTrue(label.subtitle.contains("27.47"))
    }

    func testMarketCentersAreNotLabeledCurrentLocation() {
        XCTAssertFalse(ReverseGeocodingService.isUnresolvedPickupName(MockPlaces.lubumbashiCenter.name))
        XCTAssertFalse(ReverseGeocodingService.isUnresolvedPickupName(MockPlaces.nairobiCenter.name))
        XCTAssertEqual(MockPlaces.lubumbashiCenter.name, "Avenue Mobutu")
        XCTAssertEqual(MockPlaces.nairobiCenter.name, "Kenyatta Avenue")
    }
}
