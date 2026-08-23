import XCTest
@testable import Vuum

final class CurrencyMoneyFormattingTests: XCTestCase {
    func testCurrencySymbolsAndMarketPrimary() {
        XCTAssertEqual(CurrencyCode.kes.displaySymbol, "KSh")
        XCTAssertEqual(CurrencyCode.cdf.displaySymbol, "CDF")
        XCTAssertEqual(CurrencyCode.usd.displaySymbol, "$")
        XCTAssertEqual(CurrencyCode.primary(for: .kenya), .kes)
        XCTAssertEqual(CurrencyCode.primary(for: .drc), .cdf)
        XCTAssertEqual(CurrencyCode.secondary(for: .drc), .usd)
        XCTAssertNil(CurrencyCode.secondary(for: .kenya))
    }

    func testMoneyUSDUsesCentsMinorUnits() {
        let money = Money.usd(11.5)
        XCTAssertEqual(money.minorUnits, 1_150)
        XCTAssertEqual(money.decimalAmount, 11.5, accuracy: 0.0001)
        XCTAssertEqual(money.formatted, "$11.50")
        XCTAssertEqual(CurrencyFormatter.labeledUSD(11.5), "$11.50 USD")
    }

    func testLocalMoneyFormattingIncludesCurrencySymbol() {
        let cdf = Money.local(8_500, currency: .cdf)
        XCTAssertTrue(cdf.formatted.hasPrefix("CDF "))
        XCTAssertTrue(digitsOnly(cdf.formatted).contains("8500"))

        let kes = Money.local(1_200, market: .kenya)
        XCTAssertEqual(kes.currency, .kes)
        XCTAssertTrue(kes.formatted.hasPrefix("KSh "))
        XCTAssertTrue(digitsOnly(kes.formatted).contains("1200"))
    }

    func testMoneyPairDRCShowsApproximateUSD() {
        let pair = MoneyPair.fare(local: 10_000, usd: 3.51, market: .drc)
        XCTAssertEqual(pair.primary.currency, .cdf)
        XCTAssertEqual(pair.secondary?.currency, .usd)
        let approx = pair.formattedApproximate
        XCTAssertTrue(approx.contains("CDF"))
        XCTAssertTrue(approx.contains("≈"))
        XCTAssertTrue(approx.contains("$3.51"))

        let kenya = MoneyPair.fare(local: 500, usd: 3.9, market: .kenya)
        XCTAssertNil(kenya.secondary)
        XCTAssertEqual(kenya.formatted, kenya.primary.formatted)
    }

    func testExchangeRateConversionRoundTrip() {
        let rates = ExchangeRateConfiguration(
            cdfPerUSD: 2_850,
            kesPerUSD: 129,
            asOf: Date(timeIntervalSince1970: 1_724_000_000)
        )
        XCTAssertEqual(rates.usdFromLocal(2_850, currency: .cdf), 1.0, accuracy: 0.001)
        XCTAssertEqual(rates.localFromUSD(1.0, currency: .kes), 129)

        let converted = rates.convert(Money.local(2_850, currency: .cdf), to: .usd)
        XCTAssertEqual(converted.currency, .usd)
        XCTAssertEqual(converted.decimalAmount, 1.0, accuracy: 0.01)
    }

    func testAppLocaleFormatHelpers() {
        let drc = AppLocale.formatMoney(cdfOrKes: 5_000, market: .drc)
        XCTAssertTrue(drc.hasPrefix("CDF "))
        let kenya = AppLocale.formatMoney(cdfOrKes: 800, market: .kenya)
        XCTAssertTrue(kenya.hasPrefix("KSh "))
        let discount = AppLocale.formatDiscount(1_500, market: .drc)
        XCTAssertTrue(discount.hasPrefix("−"))
        XCTAssertTrue(digitsOnly(discount).contains("1500"))

        let tier = AppLocale.formatTierPrice(cdf: 12_000, usd: 4.2, market: .drc)
        XCTAssertTrue(tier.contains("CDF"))
        XCTAssertTrue(tier.contains("$4.20") || tier.contains("4.2"))
    }

    func testMoneyArithmeticSameCurrency() {
        let a = Money.local(1_000, currency: .cdf)
        let b = Money.local(250, currency: .cdf)
        XCTAssertEqual((a + b).minorUnits, 1_250)
        XCTAssertEqual((a - b).minorUnits, 750)
        XCTAssertEqual(Money.local(-250, currency: .cdf).abs.minorUnits, 250)
    }

    private func digitsOnly(_ string: String) -> String {
        string.filter(\.isNumber)
    }
}
