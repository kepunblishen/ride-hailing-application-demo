import Foundation

/// Admin-ready rate card for a city + service category (local major units).
struct PricingRateCard: Equatable, Hashable, Codable {
    var cityID: String
    var serviceCategory: String
    var baseFare: Int
    var perKm: Double
    var perMinute: Int
    var bookingFee: Int
    var waitingPerMinute: Int
    var minimumFare: Int
    var serviceFee: Int
    var airportToll: Int
    /// Fractional tax on subtotal after discount (usually 0 for presentation markets).
    var taxRate: Double

    static func catalog(
        market: AppLocale.Market,
        serviceCategory: String,
        cityID: String = "default"
    ) -> PricingRateCard {
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        switch fareMarket {
        case .kenya:
            return PricingRateCard(
                cityID: cityID,
                serviceCategory: serviceCategory,
                baseFare: 80,
                perKm: 55.0,
                perMinute: 4,
                bookingFee: 20,
                waitingPerMinute: MockSurge.waitingPerMinute(for: .kenya),
                minimumFare: AppLocale.minimumFareLocal(for: .kenya),
                serviceFee: MockSurge.serviceFeeLocal(for: .kenya),
                airportToll: MockSurge.tollLocal(for: .kenya, isAirport: true),
                taxRate: 0
            )
        case .drc, .both:
            return PricingRateCard(
                cityID: cityID,
                serviceCategory: serviceCategory,
                baseFare: 2_000,
                perKm: 1_600.0,
                perMinute: 80,
                bookingFee: 500,
                waitingPerMinute: MockSurge.waitingPerMinute(for: .drc),
                minimumFare: AppLocale.minimumFareLocal(for: .drc),
                serviceFee: MockSurge.serviceFeeLocal(for: .drc),
                airportToll: MockSurge.tollLocal(for: .drc, isAirport: true),
                /// DRC TVA 16% on taxable fare lines (RFQ Module 2 / P05).
                taxRate: 0.16
            )
        }
    }
}

/// Inputs for the formal fare calculation layer (§44).
struct PricingInput: Equatable {
    var cityID: String
    var serviceCategory: String
    var distanceMeters: Double
    var durationMinutes: Int
    var waitingMinutes: Int
    var surgeMultiplier: Double
    var isAirportZone: Bool
    var bookingType: BookingType
    var promoDiscountLocal: Int
    var corporateDiscountLocal: Int
    var market: AppLocale.Market
    /// Tier list price used to keep itemized lines aligned with choose-ride totals.
    var listPriceLocal: Int
    var rateCard: PricingRateCard
    var rates: ExchangeRateConfiguration

    enum BookingType: String, Equatable, Codable {
        case onDemand
        case scheduled
        case corporate
        case executive
    }

    init(
        cityID: String = "default",
        serviceCategory: String,
        distanceMeters: Double,
        durationMinutes: Int? = nil,
        waitingMinutes: Int = 0,
        surgeMultiplier: Double = 1.0,
        isAirportZone: Bool = false,
        bookingType: BookingType = .onDemand,
        promoDiscountLocal: Int = 0,
        corporateDiscountLocal: Int = 0,
        market: AppLocale.Market,
        listPriceLocal: Int,
        rateCard: PricingRateCard? = nil,
        rates: ExchangeRateConfiguration = .presentation
    ) {
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        self.cityID = cityID
        self.serviceCategory = serviceCategory
        self.distanceMeters = distanceMeters
        self.durationMinutes = durationMinutes
            ?? max(1, TripGeo.etaMinutes(distanceMeters: max(distanceMeters, 1)))
        self.waitingMinutes = waitingMinutes
        self.surgeMultiplier = surgeMultiplier
        self.isAirportZone = isAirportZone
        self.bookingType = bookingType
        self.promoDiscountLocal = promoDiscountLocal
        self.corporateDiscountLocal = corporateDiscountLocal
        self.market = fareMarket
        self.listPriceLocal = listPriceLocal
        self.rateCard = rateCard ?? .catalog(market: fareMarket, serviceCategory: serviceCategory, cityID: cityID)
        self.rates = rates
    }
}

/// Outputs: itemized breakdown + typed primary / secondary money.
struct PricingResult: Equatable {
    var breakdown: FareBreakdown
    var primary: Money
    var secondary: Money?
    var currency: CurrencyCode
    var moneyPair: MoneyPair {
        MoneyPair(primary: primary, secondary: secondary)
    }
}

/// Formal pricing engine — base + distance + time + waiting + surge + airport + fees − promo/corporate.
enum PricingEngine {
    static func quote(_ input: PricingInput) -> PricingResult {
        let card = input.rateCard
        let fareMarket = input.market == .kenya ? AppLocale.Market.kenya : .drc
        let km = input.distanceMeters / 1000.0
        let minutes = max(1, input.durationMinutes)

        let distanceFare = Int((km * card.perKm).rounded())
        let timeFare = minutes * card.perMinute
        let waiting = max(0, input.waitingMinutes) * card.waitingPerMinute
        let service = card.serviceFee
        let toll = input.isAirportZone ? max(card.airportToll, 0) : 0

        let rawCore = card.baseFare + distanceFare + timeFare + card.bookingFee + waiting
        let listPrice = max(input.listPriceLocal, 1)
        let surge = max(input.surgeMultiplier, 1.0)
        let preSurgeList = surge > 1.001
            ? max(Int((Double(listPrice) / surge).rounded()), 1)
            : listPrice
        let scale = Double(preSurgeList) / Double(max(rawCore, 1))

        let baseScaled = Int(Double(card.baseFare) * scale)
        let distanceScaled = Int(Double(distanceFare) * scale)
        let timeScaled = Int(Double(timeFare) * scale)
        let bookingScaled = Int(Double(card.bookingFee) * scale)
        let waitingScaled = Int(Double(waiting) * scale)
        let coreScaled = baseScaled + distanceScaled + timeScaled + bookingScaled + waitingScaled
        let surgeFare = surge > 1.001
            ? max(Int((Double(coreScaled) * (surge - 1.0)).rounded()), 0)
            : 0

        let subtotal = coreScaled + surgeFare + toll + service
        let promo = max(input.promoDiscountLocal, 0)
        let corporate = max(input.corporateDiscountLocal, 0)
        let discount = min(promo + corporate, max(subtotal / 2, 0))
        let afterDiscount = max(subtotal - discount, 0)
        let tax = card.taxRate > 0
            ? max(Int((Double(afterDiscount) * card.taxRate).rounded()), 0)
            : 0
        let beforeMinimum = afterDiscount + tax
        let minimum = card.minimumFare
        let minimumApplied = beforeMinimum < minimum
        let total = max(beforeMinimum, minimum)
        let totalUSD = input.rates.usdFromLocal(total, market: fareMarket)

        let breakdown = FareBreakdown(
            baseFareCDF: baseScaled,
            distanceFareCDF: distanceScaled,
            timeFareCDF: timeScaled,
            bookingFeeCDF: bookingScaled,
            waitingFareCDF: waitingScaled,
            surgeMultiplier: surge,
            surgeFareCDF: surgeFare,
            tollCDF: toll,
            serviceFeeCDF: service,
            discountCDF: discount,
            taxCDF: tax,
            subtotalCDF: subtotal + tax,
            totalCDF: total,
            totalUSD: totalUSD,
            distanceKm: (km * 10).rounded() / 10,
            durationMinutes: minutes + max(0, input.waitingMinutes),
            minimumFareApplied: minimumApplied
        )

        let currency = CurrencyCode.primary(for: fareMarket)
        let primary = Money.local(total, currency: currency)
        let secondary = CurrencyCode.secondary(for: fareMarket).map { _ in Money.usd(totalUSD) }
        return PricingResult(
            breakdown: breakdown,
            primary: primary,
            secondary: secondary,
            currency: currency
        )
    }
}
