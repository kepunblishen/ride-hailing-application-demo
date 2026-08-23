import XCTest
@testable import Vuum

@MainActor
final class AuthOTPValidationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var auth: AuthFlowController!

    override func setUp() {
        super.setUp()
        suiteName = "vuum.tests.auth.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        auth = AuthFlowController(defaults: defaults)
    }

    override func tearDown() {
        auth?.reset()
        defaults?.removePersistentDomain(forName: suiteName)
        auth = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPhoneValidationRequiresMarketDigitCount() {
        auth.selectCountry(code: "+243", flag: "🇨🇩")
        auth.applyPhoneInput("970")
        XCTAssertFalse(auth.canContinuePhone)

        auth.applyPhoneInput("0970000111")
        XCTAssertEqual(auth.normalizedPhoneDigits, "970000111")
        XCTAssertTrue(AppLocale.isValidLocalNumber(auth.phoneLocal, countryCode: "+243"))
        XCTAssertTrue(auth.canContinuePhone)
    }

    func testKenyaTrunkZeroNormalizesToNineDigits() {
        auth.selectCountry(code: "+254", flag: "🇰🇪")
        auth.applyPhoneInput("0712345678")
        XCTAssertEqual(auth.normalizedPhoneDigits, "712345678")
        XCTAssertTrue(auth.canContinuePhone)
        XCTAssertEqual(AppLocale.requiredLocalDigitCount(for: "+254"), 9)
    }

    func testOTPSubmitGatesOnFourDigitsAndAttempts() {
        XCTAssertFalse(auth.canSubmitOTP)
        auth.applyOTPPaste("12ab")
        XCTAssertEqual(auth.otpCode, "12")
        XCTAssertFalse(auth.canSubmitOTP)

        auth.applyOTPPaste("9876")
        XCTAssertEqual(auth.otpDigits, ["9", "8", "7", "6"])
        XCTAssertTrue(auth.canSubmitOTP)
    }

    func testOTPPasteAndSingleDigitHelpers() {
        auth.applyOTPPaste("4321")
        XCTAssertEqual(auth.otpCode, "4321")
        auth.setOTPDigit("5", at: 0)
        XCTAssertEqual(auth.otpDigits[0], "5")
        auth.setOTPDigit("xy", at: 1)
        XCTAssertEqual(auth.otpDigits[1], "")
        auth.setOTPDigit("7", at: 99)
        XCTAssertEqual(auth.otpCode.count, 4)
    }

    func testProfileNameAndOptionalEmailRules() {
        auth.applyName("A", to: \.firstName)
        auth.applyName("B", to: \.lastName)
        XCTAssertFalse(auth.canSubmitProfile)

        auth.applyName("Amina", to: \.firstName)
        auth.applyName("Mwamba", to: \.lastName)
        auth.applyEmail("")
        XCTAssertTrue(auth.canSubmitProfile)

        auth.applyEmail("not-an-email")
        XCTAssertFalse(auth.isValidEmailIfPresent)
        XCTAssertFalse(auth.canSubmitProfile)

        auth.applyEmail("a@b.c")
        XCTAssertFalse(auth.isValidEmailIfPresent)

        auth.applyEmail("rider@vuum.app")
        XCTAssertTrue(auth.isValidEmailIfPresent)
        XCTAssertTrue(auth.canSubmitProfile)

        XCTAssertTrue(AuthFlowController.isValidOptionalEmail(""))
        XCTAssertTrue(AuthFlowController.isValidOptionalEmail("  "))
        XCTAssertFalse(AuthFlowController.isValidOptionalEmail("nope@"))
        XCTAssertFalse(AuthFlowController.isValidOptionalEmail("@vuum.app"))
        XCTAssertFalse(AuthFlowController.isValidOptionalEmail("name with space@vuum.app"))
    }

    func testMaskedPhoneShowsCountryAndLastTwoDigits() {
        auth.selectCountry(code: "+243", flag: "🇨🇩")
        auth.applyPhoneInput("970000111")
        XCTAssertTrue(auth.maskedPhoneForOTP.hasPrefix("+243"))
        XCTAssertTrue(auth.maskedPhoneForOTP.hasSuffix("11"))
    }

    func testAppLocalePhoneFormattingGroupsDigits() {
        let formatted = AppLocale.formatLocalNumber("970000111", countryCode: "+243")
        XCTAssertEqual(formatted, "970 000 111")
        XCTAssertFalse(AppLocale.isValidLocalNumber("123", countryCode: "+243"))
        XCTAssertTrue(AppLocale.isValidLocalNumber("712345678", countryCode: "+254"))
    }
}
