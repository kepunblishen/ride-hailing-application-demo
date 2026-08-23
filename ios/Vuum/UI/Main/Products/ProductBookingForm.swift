import SwiftUI

/// Shared pickup / dropoff pickers for Services product sheets.
struct ProductBookingForm<Extra: View>: View {
    @EnvironmentObject private var savedPlaces: SavedPlacesStore

    let title: String
    let subtitle: String
    let symbol: String
    let confirmTitle: String
    @Binding var pickup: Place
    @Binding var dropoff: Place
    /// Live tier used for ETA + fare preview on the form.
    var estimate: RideTier? = nil
    var canConfirm: Bool = true
    @ViewBuilder var extra: () -> Extra
    let onConfirm: () -> Void

    private var fareMarket: AppLocale.Market {
        AppLocale.current == .kenya ? .kenya : .drc
    }

    private var places: [Place] {
        let center = MockPlaces.defaultCenter(for: fareMarket)
        let catalog = MockPlaces.destinations(for: fareMarket)
        return savedPlaces.bookingPlaces(center: center, catalog: catalog)
    }

    private var routeMeters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                        .frame(width: 48, height: 48)
                        .background(VuumColor.brand.opacity(0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(L10n.Products.pickup) {
                Picker(L10n.Products.from, selection: $pickup) {
                    ForEach(places) { place in
                        Text(savedPlaces.displayTitle(for: place)).tag(place)
                    }
                }
            }

            Section(L10n.Products.dropoff) {
                Picker(L10n.Products.to, selection: $dropoff) {
                    ForEach(places.filter { $0.id != pickup.id }) { place in
                        Text(savedPlaces.displayTitle(for: place)).tag(place)
                    }
                }
            }

            extra()

            if let estimate, pickup.id != dropoff.id {
                Section("Estimate") {
                    HStack {
                        Label("Pickup ETA", systemImage: "clock")
                        Spacer()
                        Text("\(estimate.etaMinutes) min")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(VuumColor.brand)
                    }
                    HStack {
                        Label("Distance", systemImage: "road.lanes")
                        Spacer()
                        Text(TripGeo.formatDistance(routeMeters))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Capacity", systemImage: "person.fill")
                        Spacer()
                        Text("\(estimate.capacity)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Fare", systemImage: "banknote")
                        Spacer()
                        Text(estimate.priceLabel(for: fareMarket))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    Text(estimate.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    savedPlaces.recordRecent(dropoff)
                    onConfirm()
                } label: {
                    Text(confirmTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canConfirm || pickup.id == dropoff.id)
            }
        }
    }
}

enum ProductCatalogTiers {
    static func twoWheels(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 0.72).rounded())
        return RideTier(
            id: "two-wheels",
            name: "2-Wheels",
            detail: "Quick trips · bike or scooter",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .bike),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: VehicleClass.bike.systemImage,
            vehicleClass: .bike
        )
    }

    static func courier(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 0.9).rounded())
        return RideTier(
            id: "courier",
            name: "Courier",
            detail: "On-demand package delivery",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "shippingbox.fill",
            vehicleClass: .standard
        )
    }

    static func grocery(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 0.95).rounded())
        return RideTier(
            id: "grocery",
            name: "Grocery",
            detail: "Market basket delivery",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "cart.fill",
            vehicleClass: .standard
        )
    }

    static func food(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 1.05).rounded())
        return RideTier(
            id: "food",
            name: "Food",
            detail: "Restaurant order · courier delivery",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "fork.knife",
            vehicleClass: .standard
        )
    }

    static func convenience(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 0.92).rounded())
        return RideTier(
            id: "convenience",
            name: "Convenience",
            detail: "Corner-store essentials · quick drop",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "bag.fill",
            vehicleClass: .standard
        )
    }

    static func alcohol(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 1.08).rounded())
        return RideTier(
            id: "alcohol",
            name: "Alcohol",
            detail: "Licensed delivery · ID at door",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "wineglass.fill",
            vehicleClass: .standard
        )
    }

    static func health(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 2500) * 1.0).rounded())
        return RideTier(
            id: "health",
            name: "Health",
            detail: "Pharmacy essentials · priority drop",
            capacity: 1,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "cross.case.fill",
            vehicleClass: .standard
        )
    }

    static func hotelTransfer(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "comfort" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first
        let price = Int((Double(base?.priceCDF ?? 4000) * 1.05).rounded())
        return RideTier(
            id: "hotel",
            name: "Hotel transfer",
            detail: "Lobby pickup · guest name board",
            capacity: 3,
            etaMinutes: VehiclePickupETA.minutes(for: .standard),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "building.2.fill",
            vehicleClass: .standard
        )
    }

    static func hourly(distanceMeters: Double, hours: Int, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "comfort" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first
        let hoursClamped = max(1, hours)
        let price = Int((Double(base?.priceCDF ?? 3500) * Double(hoursClamped) * 0.85).rounded())
        return RideTier(
            id: "hourly",
            name: "Hourly · \(hoursClamped) hr",
            detail: "Driver stays with you for the booked time",
            capacity: 4,
            etaMinutes: VehiclePickupETA.minutes(for: .large),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "clock.fill",
            vehicleClass: .large
        )
    }

    static func airport(distanceMeters: Double, market: AppLocale.Market = AppLocale.current) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "airport" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "xxl" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first
        let price = base?.priceCDF ?? 6_000
        return RideTier(
            id: "airport",
            name: "Airport",
            detail: "Flight-friendly pickup · luggage space",
            capacity: 4,
            etaMinutes: VehiclePickupETA.minutes(for: .large),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "airplane",
            vehicleClass: .large
        )
    }

    /// Executive / VIP transfer. Meet-and-greet adds a fare premium; ETA matches XXL (~10 min).
    static func executive(
        distanceMeters: Double,
        meetAndGreet: Bool = true,
        market: AppLocale.Market = AppLocale.current
    ) -> RideTier {
        let base = MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "executive" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first(where: { $0.id == "xxl" })
            ?? MockFares.tiers(for: distanceMeters, market: market).first
        let basePrice = base?.priceCDF ?? 8_000
        let price = meetAndGreet
            ? Int((Double(basePrice) * 1.12).rounded())
            : basePrice
        let detail = meetAndGreet
            ? "Meet-and-greet · name board · top-rated drivers"
            : "Premium cars · top-rated drivers"
        return RideTier(
            id: "executive",
            name: "Executive",
            detail: detail,
            capacity: 3,
            etaMinutes: VehiclePickupETA.minutes(for: .large),
            priceCDF: price,
            priceUSD: AppLocale.usdFromLocal(price, market: market),
            systemImage: "crown.fill",
            vehicleClass: .large
        )
    }

    static func rebuild(id: String, distanceMeters: Double, hourlyHours: Int, market: AppLocale.Market) -> RideTier? {
        switch id {
        case "two-wheels":
            return twoWheels(distanceMeters: distanceMeters, market: market)
        case "courier":
            return courier(distanceMeters: distanceMeters, market: market)
        case "grocery":
            return grocery(distanceMeters: distanceMeters, market: market)
        case "food":
            return food(distanceMeters: distanceMeters, market: market)
        case "convenience":
            return convenience(distanceMeters: distanceMeters, market: market)
        case "alcohol":
            return alcohol(distanceMeters: distanceMeters, market: market)
        case "health":
            return health(distanceMeters: distanceMeters, market: market)
        case "hotel":
            return hotelTransfer(distanceMeters: distanceMeters, market: market)
        case "hourly":
            return hourly(distanceMeters: distanceMeters, hours: max(1, hourlyHours), market: market)
        case "airport":
            return airport(distanceMeters: distanceMeters, market: market)
        case "executive":
            return executive(distanceMeters: distanceMeters, market: market)
        default:
            return nil
        }
    }
}
