import SwiftUI

/// Shared pickup / dropoff pickers for Services product sheets.
/// Uses Places autocomplete when keyed (via `PlaceSearchPickerSheet`); local catalog otherwise.
struct ProductBookingForm<Extra: View>: View {
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager

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

    @State private var pickerTarget: BookingPlaceTarget?

    private var fareMarket: AppLocale.Market {
        AppLocale.current == .kenya ? .kenya : .drc
    }

    private var places: [Place] {
        let center = tripSession.pickup
        let catalog = MockPlaces.destinations(for: fareMarket)
        return savedPlaces.bookingPlaces(center: center, catalog: catalog)
    }

    private var routeMeters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var previewPins: [MapPin] {
        var pins = [
            MapPin(id: "booking-pickup", coordinate: pickup.coordinate, kind: .pickup, heading: 0),
        ]
        if pickup.id != dropoff.id {
            pins.append(
                MapPin(id: "booking-dropoff", coordinate: dropoff.coordinate, kind: .dropoff, heading: 0)
            )
        }
        return pins
    }

    private var previewFit: [GeoPoint] {
        previewPins.map(\.coordinate)
    }

    /// Straight preview segment only — no Routes/Directions billing on form open.
    private var previewRoute: [GeoPoint] {
        guard pickup.id != dropoff.id else { return [] }
        return [pickup.coordinate, dropoff.coordinate]
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

            Section {
                BookingRoutePreviewMap(
                    cameraTarget: pickup.coordinate,
                    pins: previewPins,
                    route: previewRoute,
                    fitCoordinates: previewFit
                )
                .frame(height: 148)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
                .accessibilityLabel("Map showing pickup and drop-off")
            }

            Section(L10n.Products.pickup) {
                bookingPlaceRow(
                    title: L10n.Products.from,
                    place: pickup,
                    icon: "mappin.and.ellipse"
                ) {
                    pickerTarget = .pickup
                }
            }

            Section(L10n.Products.dropoff) {
                bookingPlaceRow(
                    title: L10n.Products.to,
                    place: dropoff,
                    icon: "flag.fill"
                ) {
                    pickerTarget = .dropoff
                }
            }

            if !quickPlaces.isEmpty {
                Section(L10n.Destination.suggestions) {
                    ForEach(quickPlaces) { place in
                        Button {
                            applyQuickDropoff(place)
                        } label: {
                            Label(savedPlaces.displayTitle(for: place), systemImage: savedPlaces.systemImage(for: place))
                        }
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
        .sheet(item: $pickerTarget) { target in
            PlaceSearchPickerSheet(
                title: target == .pickup ? L10n.Products.pickup : L10n.Products.dropoff,
                bias: searchBias,
                excludePlaceIDs: target == .dropoff ? [pickup.id] : [dropoff.id]
            ) { place in
                switch target {
                case .pickup:
                    pickup = place
                    if dropoff.id == place.id, let alt = places.first(where: { $0.id != place.id }) {
                        dropoff = alt
                    }
                case .dropoff:
                    dropoff = place
                    savedPlaces.recordRecent(place)
                }
            }
        }
        .onAppear {
            seedFromLivePickupIfNeeded()
        }
    }

    private var searchBias: GeoPoint {
        if let loc = location.latestLocation {
            return GeoPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        return tripSession.pickup.coordinate
    }

    private var quickPlaces: [Place] {
        Array(
            places
                .filter { $0.id != pickup.id && $0.id != dropoff.id }
                .prefix(4)
        )
    }

    private func bookingPlaceRow(
        title: String,
        place: Place,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(savedPlaces.displayTitle(for: place))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(place.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(L10n.Destination.searchPlaces)
    }

    private func applyQuickDropoff(_ place: Place) {
        dropoff = place
        savedPlaces.recordRecent(place)
    }

    /// Prefer live Home / GPS pickup when the sheet still has a market-default seed.
    private func seedFromLivePickupIfNeeded() {
        let marketCenter = MockPlaces.defaultCenter(for: fareMarket)
        let live = tripSession.pickup
        let stillOnMarketDefault =
            pickup.id == marketCenter.id
            || pickup.id == MockPlaces.lubumbashiCenter.id
            || (
                abs(pickup.coordinate.latitude - marketCenter.coordinate.latitude) < 0.0001
                    && abs(pickup.coordinate.longitude - marketCenter.coordinate.longitude) < 0.0001
            )
        if stillOnMarketDefault {
            pickup = live
        }
        if dropoff.id == pickup.id,
           let alt = places.first(where: { $0.id != pickup.id })
        {
            dropoff = alt
        }
    }
}

private enum BookingPlaceTarget: String, Identifiable {
    case pickup
    case dropoff
    var id: String { rawValue }
}

/// Compact map strip for Services booking forms (pins + optional straight preview).
private struct BookingRoutePreviewMap: View {
    var cameraTarget: GeoPoint
    var pins: [MapPin]
    var route: [GeoPoint]
    var fitCoordinates: [GeoPoint]

    var body: some View {
        VuumMapView(
            cameraTarget: cameraTarget,
            zoom: 13,
            pins: pins,
            route: route,
            fitCoordinates: fitCoordinates,
            followDriver: false,
            contentPadding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
            showsTraffic: false,
            lowDataMode: true
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .allowsHitTesting(false)
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
