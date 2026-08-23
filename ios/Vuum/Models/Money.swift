import Foundation

/// ISO-style currency codes used across fares, wallet, and receipts.
enum CurrencyCode: String, Codable, CaseIterable, Identifiable, Hashable {
    case kes = "KES"
    case cdf = "CDF"
    case usd = "USD"

    var id: String { rawValue }

    /// Rider-facing symbol / short label (not scattered in views).
    var displaySymbol: String {
        switch self {
        case .kes: return "KSh"
        case .cdf: return "CDF"
        case .usd: return "$"
        }
    }

    /// Maps payment-ledger currency labels.
    var paymentCurrency: PaymentCurrency {
        switch self {
        case .kes: return .ksh
        case .cdf: return .cdf
        case .usd: return .usd
        }
    }

    static func primary(for market: AppLocale.Market) -> CurrencyCode {
        market == .kenya ? .kes : .cdf
    }

    static func secondary(for market: AppLocale.Market) -> CurrencyCode? {
        market == .kenya ? nil : .usd
    }
}

/// Typed amount: numeric value + currency + formatting.
struct Money: Equatable, Hashable, Codable {
    /// Whole major units for KES/CDF; USD stored as whole cents (e.g. 1150 = $11.50).
    var minorUnits: Int
    var currency: CurrencyCode

    init(minorUnits: Int, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    /// Local fare / wallet units (KES or CDF whole currency units).
    static func local(_ units: Int, currency: CurrencyCode) -> Money {
        Money(minorUnits: units, currency: currency)
    }

    static func local(_ units: Int, market: AppLocale.Market) -> Money {
        .local(units, currency: .primary(for: market == .kenya ? .kenya : .drc))
    }

    static func usd(_ amount: Double) -> Money {
        Money(minorUnits: Int((amount * 100.0).rounded()), currency: .usd)
    }

    var majorUnits: Int {
        switch currency {
        case .kes, .cdf: return minorUnits
        case .usd: return minorUnits / 100
        }
    }

    /// Decimal major amount (USD includes cents).
    var decimalAmount: Double {
        switch currency {
        case .kes, .cdf: return Double(minorUnits)
        case .usd: return Double(minorUnits) / 100.0
        }
    }

    var formatted: String {
        CurrencyFormatter.string(for: self)
    }

    var abs: Money {
        Money(minorUnits: Swift.abs(minorUnits), currency: currency)
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency)
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency)
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currency: lhs.currency)
    }
}

/// Primary (+ optional secondary) display pair for dual-currency markets.
struct MoneyPair: Equatable, Hashable {
    var primary: Money
    var secondary: Money?

    var formatted: String {
        CurrencyFormatter.string(pair: self, approximateSecondary: false)
    }

    /// DRC-style secondary with ≈ (contextual FX display).
    var formattedApproximate: String {
        CurrencyFormatter.string(pair: self, approximateSecondary: true)
    }

    static func fare(local: Int, usd: Double, market: AppLocale.Market) -> MoneyPair {
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        let primary = Money.local(local, market: fareMarket)
        let secondary = CurrencyCode.secondary(for: fareMarket).map { _ in Money.usd(usd) }
        return MoneyPair(primary: primary, secondary: secondary)
    }
}

/// Central FX rates — presentation layer should not hard-code conversion constants.
struct ExchangeRateConfiguration: Equatable, Hashable, Codable {
    /// How many CDF equal 1 USD.
    var cdfPerUSD: Double
    /// How many KES equal 1 USD.
    var kesPerUSD: Double
    /// When these rates were last refreshed (local catalog stamp).
    var asOf: Date

    /// Default presentation rates (replaceable without hunting view literals).
    static var presentation = ExchangeRateConfiguration(
        cdfPerUSD: 2850.0,
        kesPerUSD: 129.0,
        asOf: Date(timeIntervalSince1970: 1_724_000_000)
    )

    func unitsPerUSD(for currency: CurrencyCode) -> Double {
        switch currency {
        case .usd: return 1
        case .cdf: return cdfPerUSD
        case .kes: return kesPerUSD
        }
    }

    func usdFromLocal(_ amount: Int, currency: CurrencyCode) -> Double {
        switch currency {
        case .usd: return Double(amount) / 100.0
        case .kes: return Double(amount) / max(kesPerUSD, 1)
        case .cdf: return Double(amount) / max(cdfPerUSD, 1)
        }
    }

    func usdFromLocal(_ amount: Int, market: AppLocale.Market) -> Double {
        usdFromLocal(amount, currency: .primary(for: market == .kenya ? .kenya : .drc))
    }

    func localFromUSD(_ usd: Double, currency: CurrencyCode) -> Int {
        switch currency {
        case .usd: return Int((usd * 100.0).rounded())
        case .kes: return Int((usd * kesPerUSD).rounded())
        case .cdf: return Int((usd * cdfPerUSD).rounded())
        }
    }

    func convert(_ money: Money, to target: CurrencyCode) -> Money {
        if money.currency == target { return money }
        let asUSD: Double
        switch money.currency {
        case .usd: asUSD = money.decimalAmount
        case .kes, .cdf: asUSD = usdFromLocal(money.minorUnits, currency: money.currency)
        }
        switch target {
        case .usd: return .usd(asUSD)
        case .kes, .cdf: return .local(localFromUSD(asUSD, currency: target), currency: target)
        }
    }
}

/// Market-facing currency policy (primary / secondary + shared FX).
struct CurrencyConfiguration: Equatable, Hashable {
    var primary: CurrencyCode
    var secondary: CurrencyCode?
    var rates: ExchangeRateConfiguration

    static func forMarket(_ market: AppLocale.Market, rates: ExchangeRateConfiguration = .presentation) -> CurrencyConfiguration {
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        return CurrencyConfiguration(
            primary: .primary(for: fareMarket),
            secondary: .secondary(for: fareMarket),
            rates: rates
        )
    }

    func moneyPair(local: Int, usd: Double? = nil) -> MoneyPair {
        let primaryMoney = Money.local(local, currency: primary)
        let secondaryMoney: Money? = {
            guard let secondary else { return nil }
            if secondary == .usd {
                let value = usd ?? rates.usdFromLocal(local, currency: primary)
                return .usd(value)
            }
            return rates.convert(primaryMoney, to: secondary)
        }()
        return MoneyPair(primary: primaryMoney, secondary: secondaryMoney)
    }
}

enum CurrencyFormatter {
    static func string(for money: Money) -> String {
        switch money.currency {
        case .kes, .cdf:
            return "\(money.currency.displaySymbol) \(money.minorUnits.formatted())"
        case .usd:
            return String(format: "$%.2f", money.decimalAmount)
        }
    }

    static func string(pair: MoneyPair, approximateSecondary: Bool = true) -> String {
        let primary = pair.primary.formatted
        guard let secondary = pair.secondary else { return primary }
        if approximateSecondary, secondary.currency == .usd {
            return "\(primary) · ≈ \(secondary.formatted)"
        }
        return "\(primary) · \(secondary.formatted)"
    }

    static func labeledUSD(_ amount: Double) -> String {
        String(format: "$%.2f USD", amount)
    }
}
