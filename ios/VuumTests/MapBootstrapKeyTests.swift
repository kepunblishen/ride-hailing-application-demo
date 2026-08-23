import XCTest
@testable import Vuum

final class MapBootstrapKeyTests: XCTestCase {
    func testPlaceholdersAreRejected() {
        XCTAssertFalse(MapBootstrap.isUsableAPIKey(""))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("   "))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("YOUR_GOOGLE_MAPS_API_KEY"))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("$(VUUM_GOOGLE_MAPS_API_KEY)"))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("$(GMSApiKey)"))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("REPLACE_ME"))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("null"))
        XCTAssertFalse(MapBootstrap.isUsableAPIKey("short"))
    }

    func testNonPlaceholderIsAccepted() {
        // Synthetic shape only — not a real Google key; never commit live credentials.
        XCTAssertTrue(MapBootstrap.isUsableAPIKey("AIzaSyDummyTestKeyNotReal0000000000000"))
    }

    func testIOSBundleIdentifierHeaderMatchesProduct() {
        XCTAssertEqual(MapBootstrap.iosBundleIdentifier, "com.vuum.app")
        XCTAssertEqual(MapBootstrap.iosBundleIdentifierHeader, "X-Ios-Bundle-Identifier")

        var request = URLRequest(url: URL(string: "https://example.com")!)
        MapBootstrap.applyIOSBundleIdentifierHeader(to: &request)
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"),
            "com.vuum.app"
        )
    }
}
