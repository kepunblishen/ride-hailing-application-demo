import XCTest
@testable import Vuum

final class FarePromoMathTests: XCTestCase {
    private func sampleTier(priceCDF: Int = 8_000, vehicleClass: VehicleClass = .standard) -> RideTier {
        RideTier(
            id: "vuum",
            name: "Vuum",
            detail: "Test",
            capacity: 4,
            etaMinutes: VehiclePickupETA.minutes(for: vehicleClass),
            priceCDF: priceCDF,
            priceUSD: 3.2,
            systemImage: "car.fill",
            vehicleClass: vehicleClass
        )
    }

    func testFareBreakdownAppliesDiscountAndKeepsMinimum() {
        let tier = sampleTier(priceCDF: 8_000)
        let full = MockFares.breakdown(
            distanceMeters: 4_500,
            tier: tier,
            discountCDF: 0,
            market: .drc
        )
        let discounted = MockFares.breakdown(
            distanceMeters: 4_500,
            tier: tier,
            discountCDF: 1_500,
            market: .drc
        )

        XCTAssertGreaterThan(full.totalCDF, 0)
        XCTAssertGreaterThan(discounted.discountCDF, 0)
        XCTAssertLessThanOrEqual(discounted.discountCDF, 1_500)
        XCTAssertLessThanOrEqual(discounted.totalCDF, full.totalCDF)
        XCTAssertGreaterThanOrEqual(discounted.totalCDF, AppLocale.minimumFareLocal(for: .drc))
    }

    func testFareBreakdownCapsDiscountAtHalfSubtotal() {
        let tier = sampleTier(priceCDF: 6_000)
        let hugeDiscount = MockFares.breakdown(
            distanceMeters: 3_000,
            tier: tier,
            discountCDF: 100_000,
            market: .drc
        )
        // Discount is capped; total still respects market minimum.
        XCTAssertLessThan(hugeDiscount.discountCDF, 100_000)
        XCTAssertGreaterThanOrEqual(hugeDiscount.totalCDF, AppLocale.minimumFareLocal(for: .drc))
    }

    func testFareBreakdownIncludesWaitingWhenStopsPresent() {
        let tier = sampleTier()
        let none = MockFares.breakdown(
            distanceMeters: 4_000,
            tier: tier,
            waitingMinutes: 0,
            market: .drc
        )
        let withWait = MockFares.breakdown(
            distanceMeters: 4_000,
            tier: tier,
            waitingMinutes: 4,
            market: .drc
        )
        XCTAssertEqual(none.waitingFareCDF, 0)
        XCTAssertGreaterThan(withWait.waitingFareCDF, 0)
        XCTAssertEqual(withWait.durationMinutes, none.durationMinutes + 4)
    }

    func testSurgeAddsExplicitLine() {
        let tier = sampleTier(priceCDF: 10_000)
        let surged = MockFares.breakdown(
            distanceMeters: 5_000,
            tier: tier,
            surgeMultiplier: 1.5,
            market: .drc
        )
        XCTAssertTrue(surged.isSurgeActive)
        XCTAssertGreaterThan(surged.surgeFareCDF, 0)
        XCTAssertEqual(surged.surgeMultiplier, 1.5, accuracy: 0.001)
    }

    @MainActor
    func testPromoValidationAppliedInvalidExpiredAndAirportGate() {
        let suiteName = "vuum.tests.promo.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PromoCodesStore(defaults: defaults)

        let applied = store.validate(
            code: "VUUM10",
            market: .drc,
            estimatedFareLocal: 6_000,
            isAirportTrip: false
        )
        if case let .applied(code, discount, _) = applied {
            XCTAssertEqual(code, "VUUM10")
            XCTAssertEqual(discount, 1_500)
        } else {
            XCTFail("Expected VUUM10 to apply, got \(applied)")
        }

        XCTAssertEqual(
            store.validate(code: "NOPE", market: .drc, estimatedFareLocal: 6_000, isAirportTrip: false),
            .invalid
        )
        XCTAssertEqual(
            store.validate(code: "OLDCODE", market: .drc, estimatedFareLocal: 6_000, isAirportTrip: false),
            .expired
        )

        let airportOnly = store.validate(
            code: "AIRPORT20",
            market: .drc,
            estimatedFareLocal: 10_000,
            isAirportTrip: false
        )
        if case .notEligible = airportOnly {
            // expected
        } else {
            XCTFail("Expected airport-only gate, got \(airportOnly)")
        }

        let percent = store.validate(
            code: "PEAK15",
            market: .drc,
            estimatedFareLocal: 10_000,
            isAirportTrip: false
        )
        if case let .applied(_, discount, _) = percent {
            XCTAssertEqual(discount, 1_500)
        } else {
            XCTFail("Expected PEAK15 percent discount, got \(percent)")
        }
    }

    func testPercentPromoOfferMath() {
        let offer = PromoOffer(
            code: "PCT20",
            title: "Twenty",
            detail: "Test",
            discountCDF: 0,
            discountKSh: 0,
            percentOff: 20,
            expiresAt: nil,
            minFareLocalDRC: 0,
            minFareLocalKenya: 0,
            airportOnly: false,
            usesRemaining: nil
        )
        XCTAssertEqual(offer.discount(for: .drc, fareLocal: 5_000), 1_000)
        XCTAssertEqual(offer.discount(for: .kenya, fareLocal: 500), 100)
    }
}
