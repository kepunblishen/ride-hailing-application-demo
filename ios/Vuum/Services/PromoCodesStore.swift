import Combine
import Foundation

enum PromoValidationStatus: Equatable {
    case idle
    case applied(code: String, discountLocal: Int, title: String)
    case invalid
    case expired
    case notEligible(reason: String)
}

struct PromoOffer: Identifiable, Equatable, Codable, Hashable {
    var id: String { code }
    let code: String
    let title: String
    let detail: String
    /// Fixed discount in DRC local units (CDF).
    let discountCDF: Int
    /// Fixed discount in Kenya local units (KSh).
    let discountKSh: Int
    /// Optional percent off (0–100); when > 0, overrides fixed discount.
    let percentOff: Int
    let expiresAt: Date?
    let minFareLocalDRC: Int
    let minFareLocalKenya: Int
    /// When true, only airport / premium zone trips.
    let airportOnly: Bool
    var usesRemaining: Int?

    func discount(for market: AppLocale.Market, fareLocal: Int) -> Int {
        let resolved: AppLocale.Market = market == .kenya ? .kenya : .drc
        if percentOff > 0 {
            return max(0, Int((Double(fareLocal) * Double(percentOff) / 100.0).rounded()))
        }
        return resolved == .kenya ? discountKSh : discountCDF
    }

    func minFare(for market: AppLocale.Market) -> Int {
        market == .kenya ? minFareLocalKenya : minFareLocalDRC
    }
}

/// Catalog + saved promo codes with validation (apply / invalid / expired / restrictions).
@MainActor
final class PromoCodesStore: ObservableObject {
    private enum Keys {
        static let saved = "vuum.promo.saved"
        static let uses = "vuum.promo.uses"
    }

    @Published private(set) var catalog: [PromoOffer]
    @Published private(set) var savedCodes: [String]
    @Published private(set) var lastStatus: PromoValidationStatus = .idle

    private let defaults: UserDefaults
    private var usesByCode: [String: Int]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        catalog = Self.defaultCatalog
        savedCodes = defaults.stringArray(forKey: Keys.saved) ?? ["VUUM10", "WELCOME"]
        if let data = defaults.data(forKey: Keys.uses),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            usesByCode = decoded
        } else {
            usesByCode = [:]
        }
    }

    var savedOffers: [PromoOffer] {
        savedCodes.compactMap { offer(for: $0) }
    }

    func offer(for code: String) -> PromoOffer? {
        let normalized = Self.normalize(code)
        return catalog.first { $0.code == normalized }
    }

    @discardableResult
    func save(_ code: String) -> Bool {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty, !savedCodes.contains(normalized) else { return false }
        guard offer(for: normalized) != nil || !normalized.isEmpty else { return false }
        savedCodes.insert(normalized, at: 0)
        defaults.set(savedCodes, forKey: Keys.saved)
        return true
    }

    func remove(_ code: String) {
        let normalized = Self.normalize(code)
        savedCodes.removeAll { $0 == normalized }
        defaults.set(savedCodes, forKey: Keys.saved)
    }

    /// Validates and returns discount for the current booking context.
    @discardableResult
    func validate(
        code: String,
        market: AppLocale.Market,
        estimatedFareLocal: Int,
        isAirportTrip: Bool
    ) -> PromoValidationStatus {
        let normalized = Self.normalize(code)
        guard !normalized.isEmpty else {
            lastStatus = .idle
            return .idle
        }

        guard var offer = offer(for: normalized) else {
            lastStatus = .invalid
            return .invalid
        }

        if let expires = offer.expiresAt, expires < Date() {
            lastStatus = .expired
            return .expired
        }

        let remaining = usesByCode[normalized] ?? offer.usesRemaining
        if let remaining, remaining <= 0 {
            lastStatus = .notEligible(reason: "This code has no uses left")
            return lastStatus
        }

        if offer.airportOnly, !isAirportTrip {
            lastStatus = .notEligible(reason: "This code is for airport trips")
            return lastStatus
        }

        let minFare = offer.minFare(for: market)
        if estimatedFareLocal < minFare {
            lastStatus = .notEligible(reason: "Ride total is below the promo minimum")
            return lastStatus
        }

        let discount = min(
            offer.discount(for: market, fareLocal: estimatedFareLocal),
            max(estimatedFareLocal / 2, 0)
        )
        guard discount > 0 else {
            lastStatus = .invalid
            return .invalid
        }

        lastStatus = .applied(code: normalized, discountLocal: discount, title: offer.title)
        _ = save(normalized)
        return lastStatus
    }

    func clearStatus() {
        lastStatus = .idle
    }

    func consumeUse(for code: String) {
        let normalized = Self.normalize(code)
        guard let offer = offer(for: normalized) else { return }
        let current = usesByCode[normalized] ?? offer.usesRemaining
        guard let current else { return }
        usesByCode[normalized] = max(current - 1, 0)
        if let data = try? JSONEncoder().encode(usesByCode) {
            defaults.set(data, forKey: Keys.uses)
        }
    }

    private static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static var defaultCatalog: [PromoOffer] {
        let calendar = Calendar.current
        let expired = calendar.date(byAdding: .day, value: -14, to: Date())
        let soon = calendar.date(byAdding: .day, value: 45, to: Date())
        return [
            PromoOffer(
                code: "VUUM10",
                title: "VUUM welcome",
                detail: "Fixed credit off your next ride",
                discountCDF: 1_500,
                discountKSh: 50,
                percentOff: 0,
                expiresAt: soon,
                minFareLocalDRC: 3_000,
                minFareLocalKenya: 200,
                airportOnly: false,
                usesRemaining: 5
            ),
            PromoOffer(
                code: "WELCOME",
                title: "First rides",
                detail: "New rider credit",
                discountCDF: 2_000,
                discountKSh: 80,
                percentOff: 0,
                expiresAt: soon,
                minFareLocalDRC: 2_500,
                minFareLocalKenya: 180,
                airportOnly: false,
                usesRemaining: 3
            ),
            PromoOffer(
                code: "PEAK15",
                title: "Peak saver",
                detail: "15% off during high demand",
                discountCDF: 0,
                discountKSh: 0,
                percentOff: 15,
                expiresAt: soon,
                minFareLocalDRC: 4_000,
                minFareLocalKenya: 250,
                airportOnly: false,
                usesRemaining: 10
            ),
            PromoOffer(
                code: "AIRPORT20",
                title: "Airport transfer",
                detail: "Airport trips only",
                discountCDF: 3_000,
                discountKSh: 120,
                percentOff: 0,
                expiresAt: soon,
                minFareLocalDRC: 5_000,
                minFareLocalKenya: 400,
                airportOnly: true,
                usesRemaining: 4
            ),
            PromoOffer(
                code: "OLDCODE",
                title: "Seasonal offer",
                detail: "Expired promotion",
                discountCDF: 1_000,
                discountKSh: 40,
                percentOff: 0,
                expiresAt: expired,
                minFareLocalDRC: 1_000,
                minFareLocalKenya: 100,
                airportOnly: false,
                usesRemaining: 0
            ),
        ]
    }
}
