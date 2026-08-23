import Combine
import CoreLocation
import Foundation

/// Location-aware presentation market for rider UI (currency, phone defaults, places).
@MainActor
final class AppLocale: ObservableObject {
    nonisolated enum Market: Equatable, Sendable {
        case kenya
        case drc
        /// No clear market — list both Kenya and DRC mobile-money options.
        case both
    }

    nonisolated enum Override: String, CaseIterable, Sendable {
        case auto
        case kenya
        case drc
    }

    nonisolated struct DialCountry: Identifiable, Equatable, Hashable, Sendable {
        var id: String { code }
        let flag: String
        let code: String
        let name: String
        /// National significant number length (no country code, no leading 0).
        let localDigitCount: Int
        let phonePlaceholder: String

        var flagLabel: String { "\(flag) \(code)" }
    }

    nonisolated static let overrideKey = "vuum.marketOverride"

    /// FX rates live in `ExchangeRateConfiguration` — keep aliases for older call sites.
    nonisolated static var cdfPerUSD: Double { ExchangeRateConfiguration.presentation.cdfPerUSD }
    nonisolated static var kesPerUSD: Double { ExchangeRateConfiguration.presentation.kesPerUSD }

    nonisolated static var exchangeRates: ExchangeRateConfiguration { .presentation }

    nonisolated static func currencyConfiguration(for market: Market = current) -> CurrencyConfiguration {
        .forMarket(market, rates: .presentation)
    }

    /// Active presentation market for places / fares (never `.both`).
    @Published private(set) var market: Market
    @Published private(set) var override: Override
    @Published private(set) var detectedMarket: Market

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Override(rawValue: (defaults.string(forKey: Self.overrideKey) ?? "auto").lowercased()) ?? .auto
        let detected = Self.detectFromDevice()
        self.override = stored
        self.detectedMarket = detected
        self.market = Self.resolvedMarket(override: stored, detected: detected)
    }

    // MARK: - Instance helpers

    var defaultCountryCode: String {
        market == .kenya ? "+254" : "+243"
    }

    var defaultCountryFlag: String {
        Self.flag(for: defaultCountryCode)
    }

    var currencyPrimaryLabel: String {
        market == .kenya ? "KSh" : "CDF"
    }

    var marketDisplayName: String {
        switch market {
        case .kenya: return L10n.Settings.marketKenya
        case .drc, .both: return L10n.Settings.marketDRC
        }
    }

    var homeTagline: String {
        market == .kenya ? L10n.Home.taglineKenya : L10n.Home.tagline
    }

    var phonePlaceholder: String {
        Self.phonePlaceholder(for: defaultCountryCode)
    }

    var showsUSDAlongside: Bool {
        market != .kenya
    }

    var destinations: [Place] {
        MockPlaces.destinations(for: fareMarket)
    }

    var defaultCenter: Place {
        MockPlaces.defaultCenter(for: fareMarket)
    }

    /// Places / fare market — maps `.both` → `.drc`.
    var fareMarket: Market {
        market == .kenya ? .kenya : .drc
    }

    var minimumFareLocal: Int {
        fareMarket == .kenya ? 150 : 1_000
    }

    var samplePromoDiscountLocal: Int {
        fareMarket == .kenya ? 50 : 1_500
    }

    var currencyConfiguration: CurrencyConfiguration {
        .forMarket(fareMarket, rates: .presentation)
    }

    func formatMoney(cdfOrKes: Int) -> String {
        Money.local(cdfOrKes, market: fareMarket).formatted
    }

    func formatMoney(cdfOrKes: Int, usd: Double?) -> String {
        currencyConfiguration.moneyPair(local: cdfOrKes, usd: usd).formatted
    }

    func usdFromLocal(_ amount: Int) -> Double {
        Self.usdFromLocal(amount, market: fareMarket)
    }

    func setOverride(_ value: Override) {
        override = value
        defaults.set(value.rawValue, forKey: Self.overrideKey)
        resolveMarket()
    }

    /// Update detection from Core Location. Safe to call often; UI market only changes when resolved value changes.
    func update(from location: CLLocation?) {
        if let location, let fromCoord = Self.market(for: location.coordinate) {
            detectedMarket = fromCoord
        }
        resolveMarket()
    }

    func refreshDeviceFallback() {
        detectedMarket = Self.detectFromDevice()
        resolveMarket()
    }

    private func resolveMarket() {
        let next = Self.resolvedMarket(override: override, detected: detectedMarket)
        if next != market {
            market = next
        }
    }

    nonisolated private static func resolvedMarket(override: Override, detected: Market) -> Market {
        switch override {
        case .auto: return detected == .kenya ? .kenya : .drc
        case .kenya: return .kenya
        case .drc: return .drc
        }
    }

    // MARK: - Static API (auth, payments, bootstrapping)
    // Pure market / FX / phone helpers are `nonisolated` so MockCatalog, ProductCatalogTiers,
    // and other non-UI call sites stay usable off the main actor under Swift 6.

    /// Supported dialing destinations for Get Started country picker.
    nonisolated static let dialCountries: [DialCountry] = [
        DialCountry(flag: "🇨🇩", code: "+243", name: "DR Congo", localDigitCount: 9, phonePlaceholder: "970 000 000"),
        DialCountry(flag: "🇰🇪", code: "+254", name: "Kenya", localDigitCount: 9, phonePlaceholder: "712 345 678"),
        DialCountry(flag: "🇺🇬", code: "+256", name: "Uganda", localDigitCount: 9, phonePlaceholder: "712 345 678"),
        DialCountry(flag: "🇹🇿", code: "+255", name: "Tanzania", localDigitCount: 9, phonePlaceholder: "712 345 678"),
        DialCountry(flag: "🇿🇲", code: "+260", name: "Zambia", localDigitCount: 9, phonePlaceholder: "97 123 4567"),
        DialCountry(flag: "🇺🇸", code: "+1", name: "United States", localDigitCount: 10, phonePlaceholder: "202 555 0100"),
        DialCountry(flag: "🇬🇧", code: "+44", name: "United Kingdom", localDigitCount: 10, phonePlaceholder: "7700 900123"),
    ]

    /// Presentation market from override or device (no live location). Defaults to DRC.
    nonisolated static var presentationMarket: Market {
        resolvePresentationMarket()
    }

    /// Snapshot used by MockFares / TripSession when no `EnvironmentObject` is in scope.
    /// Always `.kenya` or `.drc` (never `.both`).
    nonisolated static var current: Market {
        let m = presentationMarket
        return m == .kenya ? .kenya : .drc
    }

    nonisolated static var minimumFareLocal: Int {
        minimumFareLocal(for: current)
    }

    nonisolated static var samplePromoDiscountLocal: Int {
        samplePromoDiscountLocal(for: current)
    }

    nonisolated static func usdFromLocal(_ amount: Int) -> Double {
        usdFromLocal(amount, market: current)
    }

    nonisolated static func resolvePresentationMarket(
        locale: Locale = .current,
        defaults: UserDefaults = .standard
    ) -> Market {
        let stored = Override(rawValue: (defaults.string(forKey: overrideKey) ?? "auto").lowercased()) ?? .auto
        switch stored {
        case .kenya: return .kenya
        case .drc: return .drc
        case .auto:
            return detectFromDevice(locale: locale)
        }
    }

    nonisolated static var defaultCountryCode: String {
        presentationMarket == .kenya ? "+254" : "+243"
    }

    nonisolated static var defaultCountryFlag: String {
        flag(for: defaultCountryCode)
    }

    nonisolated static var defaultPhonePlaceholder: String {
        phonePlaceholder(for: defaultCountryCode)
    }

    nonisolated static var dialCountriesOrderedForPresentation: [DialCountry] {
        let preferred = defaultCountryCode
        var list = dialCountries
        if let idx = list.firstIndex(where: { $0.code == preferred }), idx != 0 {
            let item = list.remove(at: idx)
            list.insert(item, at: 0)
        }
        return list
    }

    nonisolated static func dialCountry(for code: String) -> DialCountry? {
        dialCountries.first { $0.code == code }
    }

    nonisolated static func flag(for countryCode: String) -> String {
        switch countryCode {
        case "+254": return "🇰🇪"
        case "+243": return "🇨🇩"
        case "+256": return "🇺🇬"
        case "+255": return "🇹🇿"
        case "+250": return "🇷🇼"
        case "+257": return "🇧🇮"
        case "+211": return "🇸🇸"
        case "+251": return "🇪🇹"
        case "+234": return "🇳🇬"
        case "+233": return "🇬🇭"
        case "+27": return "🇿🇦"
        case "+971": return "🇦🇪"
        case "+44": return "🇬🇧"
        case "+1": return "🇺🇸"
        case "+33": return "🇫🇷"
        case "+32": return "🇧🇪"
        case "+91": return "🇮🇳"
        case "+86": return "🇨🇳"
        default: return dialCountry(for: countryCode)?.flag ?? "🏳️"
        }
    }

    nonisolated static func flagLabel(for countryCode: String) -> String {
        "\(flag(for: countryCode)) \(countryCode)"
    }

    nonisolated static func phonePlaceholder(for countryCode: String) -> String {
        if let known = dialCountry(for: countryCode) {
            return known.phonePlaceholder
        }
        switch countryCode {
        case "+250": return "788 123 456"
        case "+257": return "79 12 34 56"
        case "+211": return "912 345 678"
        case "+251": return "91 234 5678"
        case "+234": return "802 123 4567"
        case "+233": return "24 123 4567"
        case "+27": return "82 123 4567"
        case "+971": return "50 123 4567"
        case "+33": return "6 12 34 56 78"
        case "+32": return "470 12 34 56"
        case "+91": return "98765 43210"
        case "+86": return "138 0013 8000"
        default: return "712 345 678"
        }
    }

    nonisolated static func requiredLocalDigitCount(for countryCode: String) -> Int {
        if let known = dialCountry(for: countryCode) {
            return known.localDigitCount
        }
        switch countryCode {
        case "+257": return 8
        case "+1", "+44", "+234", "+91": return 10
        case "+86": return 11
        default: return 9
        }
    }

    /// Strip a single leading trunk `0` so `0712…` validates as 9 national digits.
    nonisolated static func normalizedLocalDigits(_ raw: String) -> String {
        var digits = raw.filter(\.isNumber)
        if digits.hasPrefix("0") {
            digits = String(digits.dropFirst())
        }
        return digits
    }

    nonisolated static func isValidLocalNumber(_ raw: String, countryCode: String) -> Bool {
        normalizedLocalDigits(raw).count == requiredLocalDigitCount(for: countryCode)
    }

    /// Light grouping for national numbers (KE/CD-style 3-3-3, US 3-3-4, etc.).
    nonisolated static func formatLocalNumber(_ raw: String, countryCode: String) -> String {
        let digits = normalizedLocalDigits(raw)
        guard !digits.isEmpty else { return "" }
        let groups: [Int]
        switch countryCode {
        case "+1":
            groups = [3, 3, 4]
        case "+44":
            groups = [4, 3, 3]
        case "+27", "+233", "+971":
            groups = [2, 3, 4]
        default:
            groups = [3, 3, 3]
        }
        var parts: [String] = []
        var idx = digits.startIndex
        for size in groups {
            guard idx < digits.endIndex else { break }
            let end = digits.index(idx, offsetBy: size, limitedBy: digits.endIndex) ?? digits.endIndex
            parts.append(String(digits[idx..<end]))
            idx = end
        }
        if idx < digits.endIndex {
            parts.append(String(digits[idx...]))
        }
        return parts.joined(separator: " ")
    }

    /// Resolve market from dialing code (`+254` Kenya, `+243` DRC). Unknown → `.both`.
    nonisolated static func market(countryCode: String?) -> Market {
        switch countryCode {
        case "+254": return .kenya
        case "+243": return .drc
        default: return .both
        }
    }

    nonisolated static func mobileMoneyMethods(for market: Market) -> [PaymentMethod] {
        switch market {
        case .kenya:
            return [.mpesa, .airtelMoney]
        case .drc:
            return [.orangeMoney, .airtelMoney]
        case .both:
            return [.mpesa, .airtelMoney, .orangeMoney]
        }
    }

    nonisolated static func ridePaymentMethods(for market: Market) -> [PaymentMethod] {
        [.cash, .wallet] + mobileMoneyMethods(for: market) + [.card]
    }

    nonisolated static func currencySubtitle(for market: Market) -> String {
        switch market {
        case .kenya: return "KSh"
        case .drc: return "CDF & USD"
        case .both: return "KSh · CDF & USD"
        }
    }

    nonisolated static func currencyPrimaryLabel(for market: Market) -> String {
        market == .kenya ? "KSh" : "CDF"
    }

    nonisolated static func formatMoney(cdfOrKes: Int, market: Market) -> String {
        Money.local(cdfOrKes, market: market == .kenya ? .kenya : .drc).formatted
    }

    nonisolated static func formatTierPrice(cdf: Int, usd: Double, market: Market) -> String {
        let fareMarket: Market = market == .kenya ? .kenya : .drc
        if fareMarket == .kenya {
            // Prefer explicit local units when already KES; else derive from USD via FX config.
            let local = cdf > 0 ? cdf : exchangeRates.localFromUSD(usd, currency: .kes)
            return Money.local(local, currency: .kes).formatted
        }
        return MoneyPair.fare(local: cdf, usd: usd, market: .drc).formatted
    }

    nonisolated static func formatFareTotal(cdf: Int, usd: Double, market: Market) -> String {
        formatTierPrice(cdf: cdf, usd: usd, market: market)
    }

    nonisolated static func formatMoneyPair(_ pair: MoneyPair) -> String {
        pair.formatted
    }

    nonisolated static func formatPrimary(local: Int, market: Market = current) -> String {
        Money.local(local, market: market == .kenya ? .kenya : .drc).formatted
    }

    nonisolated static func formatDiscount(_ amount: Int, market: Market = current) -> String {
        "−\(formatPrimary(local: amount, market: market))"
    }

    nonisolated static func formatUSDLabeled(_ usd: Double) -> String {
        CurrencyFormatter.labeledUSD(usd)
    }

    nonisolated static func formatSecondaryUSD(local: Int, usd: Double? = nil, market: Market = current) -> String? {
        guard market != .kenya else { return nil }
        let value = usd ?? usdFromLocal(local, market: .drc)
        return Money.usd(value).formatted
    }

    nonisolated static func usdFromLocal(_ amount: Int, market: Market) -> Double {
        exchangeRates.usdFromLocal(amount, market: market)
    }

    nonisolated static func minimumFareLocal(for market: Market) -> Int {
        market == .kenya ? 150 : 1_000
    }

    nonisolated static func samplePromoDiscountLocal(for market: Market) -> Int {
        market == .kenya ? 50 : 1_500
    }

    nonisolated static func detectFromDevice(locale: Locale = .current) -> Market {
        if let region = locale.region?.identifier.uppercased() {
            if region == "KE" { return .kenya }
            if region == "CD" { return .drc }
        }
        let tz = TimeZone.current.identifier
        if tz == "Africa/Nairobi" { return .kenya }
        if tz.hasPrefix("Africa/Lubumbashi") || tz.hasPrefix("Africa/Kinshasa") {
            return .drc
        }
        return .drc
    }

    nonisolated static func market(for coordinate: CLLocationCoordinate2D) -> Market? {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        if lat >= -4.9, lat <= 5.6, lon >= 33.7, lon <= 42.0 {
            return .kenya
        }
        if lat >= -13.6, lat <= 5.5, lon >= 12.0, lon <= 31.4 {
            return .drc
        }
        return nil
    }
}

/// Fare helpers used by `MockFares` / `TripSession` — mirrors the active presentation market.
enum MarketConfig {
    static var current: AppLocale.Market {
        let m = AppLocale.presentationMarket
        return m == .kenya ? .kenya : .drc
    }

    static var showsDualCurrency: Bool { current != .kenya }

    static var currencyConfiguration: CurrencyConfiguration {
        .forMarket(current)
    }

    static var exchangeRates: ExchangeRateConfiguration { .presentation }

    static var minimumFareLocal: Int {
        AppLocale.minimumFareLocal(for: current)
    }

    static var samplePromoDiscountLocal: Int {
        AppLocale.samplePromoDiscountLocal(for: current)
    }

    static func usdFromLocal(_ amount: Int) -> Double {
        exchangeRates.usdFromLocal(amount, market: current)
    }

    static func formatPrimary(local: Int) -> String {
        Money.local(local, market: current).formatted
    }

    static func formatUSD(_ amount: Double) -> String {
        Money.usd(amount).formatted
    }

    static func formatUSDLabeled(_ amount: Double) -> String {
        CurrencyFormatter.labeledUSD(amount)
    }

    static func formatSecondaryUSD(local: Int, usd: Double? = nil) -> String? {
        guard showsDualCurrency else { return nil }
        return formatUSD(usd ?? usdFromLocal(local))
    }

    static func formatDiscount(_ amount: Int) -> String {
        "−\(formatPrimary(local: amount))"
    }

    static func moneyPair(local: Int, usd: Double? = nil) -> MoneyPair {
        currencyConfiguration.moneyPair(local: local, usd: usd)
    }
}
