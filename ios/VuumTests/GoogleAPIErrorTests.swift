import XCTest
@testable import Vuum

final class GoogleAPIErrorTests: XCTestCase {
    func testHTTP403IsNotRetryable() {
        let error = GoogleAPIError.mapHTTP(403)
        XCTAssertEqual(error.diagnosticCode, "HTTP_403")
        XCTAssertFalse(error.isRetryable)
        XCTAssertFalse(error.riderMessage.isEmpty)
        XCTAssertFalse(error.riderMessage.lowercased().contains("google"))
        XCTAssertFalse(error.riderMessage.lowercased().contains("403"))
    }

    func testHTTP429And503AreRetryable() {
        XCTAssertTrue(GoogleAPIError.mapHTTP(429).isRetryable)
        XCTAssertTrue(GoogleAPIError.mapHTTP(503).isRetryable)
        XCTAssertFalse(GoogleAPIError.mapHTTP(400).isRetryable)
    }

    func testGoogleStatusMapping() {
        XCTAssertNil(GoogleAPIError.mapGoogleStatus("OK"))
        let denied = GoogleAPIError.mapGoogleStatus("REQUEST_DENIED")
        XCTAssertEqual(denied?.diagnosticCode, "REQUEST_DENIED")
        XCTAssertFalse(denied?.isRetryable ?? true)
        XCTAssertTrue(GoogleAPIError.mapGoogleStatus("OVER_QUERY_LIMIT")?.isRetryable ?? false)
    }

    func testNetworkTimeoutIsRetryable() {
        let error = GoogleAPIError.mapURLError(URLError(.timedOut))
        XCTAssertTrue(error.isRetryable)
        XCTAssertEqual(error.riderMessageKey, "maps.error_timeout")
    }

    func testRetryCap() {
        XCTAssertEqual(GoogleAPIHTTP.maxAttempts, 3)
        XCTAssertGreaterThan(GoogleAPIHTTP.baseBackoffNanoseconds, 0)
    }
}
