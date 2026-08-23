import XCTest
@testable import Vuum

final class PlacesSearchLocalCatalogTests: XCTestCase {
    func testLocalSuggestionsMatchPrefix() {
        let hits = PlacesSearchService.localSuggestions(query: "air", market: .drc)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.allSatisfy { !$0.isRemote })
        XCTAssertTrue(hits.contains { $0.primaryText.localizedCaseInsensitiveContains("air")
            || $0.secondaryText.localizedCaseInsensitiveContains("air") })
    }

    func testLocalSuggestionsEmptyQueryReturnsNothing() {
        XCTAssertTrue(PlacesSearchService.localSuggestions(query: "   ", market: .kenya).isEmpty)
    }

    func testAutocompleteWithoutKeyUsesLocalCatalog() async {
        let outcome = await PlacesSearchService.autocompleteOutcome(
            query: "lub",
            bias: nil,
            market: .drc
        )
        if PlacesSearchService.isLivePlacesAvailable {
            // Live path may return remote or fall back; still must not crash or return garbage.
            XCTAssertTrue(
                outcome.source == .remote
                    || outcome.source == .localCatalog
                    || outcome.source == .localAfterRemoteFailure
            )
        } else {
            XCTAssertEqual(outcome.source, .localCatalog)
            XCTAssertFalse(outcome.suggestions.isEmpty)
            XCTAssertTrue(outcome.suggestions.allSatisfy { !$0.isRemote })
        }
    }

    func testRecommendedDebounceIsBounded() {
        XCTAssertGreaterThanOrEqual(PlacesSearchService.recommendedDebounceMilliseconds, 250)
        XCTAssertLessThanOrEqual(PlacesSearchService.recommendedDebounceMilliseconds, 400)
    }

    func testSessionBeginAbandonDoNotCrash() {
        PlacesSearchService.beginSession()
        PlacesSearchService.abandonSession()
        PlacesSearchService.beginSession()
        PlacesSearchService.endSession()
    }

    func testLocalAirportSuggestionGetsAirportCategory() {
        let hits = PlacesSearchService.localSuggestions(query: "airport", market: .drc)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.contains { $0.category == .airport })
        XCTAssertTrue(hits.contains { $0.systemImage == "airplane" })
    }

    func testLocalSuggestionsIncludeDistanceHintWhenBiased() {
        let bias = MockPlaces.lubumbashiCenter.coordinate
        let hits = PlacesSearchService.localSuggestions(query: "airport", market: .drc, bias: bias)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertTrue(hits.contains { $0.distanceHint != nil })
        XCTAssertTrue(hits.contains { !$0.compactSubtitle.isEmpty })
    }

    func testPlaceCategoryInfersFromGoogleTypes() {
        XCTAssertEqual(
            PlaceCategory.infer(googleTypes: ["airport"], name: "X", subtitle: ""),
            .airport
        )
        XCTAssertEqual(
            PlaceCategory.infer(googleTypes: ["lodging"], name: "X", subtitle: ""),
            .hotel
        )
        XCTAssertEqual(
            PlaceCategory.infer(googleTypes: ["street_address"], name: "12 Main", subtitle: "Nairobi"),
            .address
        )
    }

    func testBoundedTTLCacheEvictsAndExpires() {
        let cache = BoundedTTLCache<String, Int>(capacity: 2, ttl: 60)
        cache.set(1, for: "a")
        cache.set(2, for: "b")
        cache.set(3, for: "c")
        XCTAssertNil(cache.value(for: "a"))
        XCTAssertEqual(cache.value(for: "b"), 2)
        XCTAssertEqual(cache.value(for: "c"), 3)
        XCTAssertEqual(cache.count, 2)

        let expired = BoundedTTLCache<String, Int>(capacity: 4, ttl: 1)
        expired.set(9, for: "x", now: Date(timeIntervalSince1970: 0))
        XCTAssertNil(expired.value(for: "x", now: Date(timeIntervalSince1970: 5)))
    }

    func testMapsRequestCachePlaceRoundTrip() {
        MapsRequestCache.clearAll()
        let place = Place(
            id: "test-place",
            name: "Test",
            subtitle: "Lubumbashi",
            coordinate: GeoPoint(latitude: -11.66, longitude: 27.48)
        )
        MapsRequestCache.storePlace(place, resourceName: "places/test-place")
        XCTAssertEqual(MapsRequestCache.cachedPlace(resourceName: "places/test-place"), place)
        MapsRequestCache.clearAll()
        XCTAssertNil(MapsRequestCache.cachedPlace(resourceName: "places/test-place"))
    }
}
