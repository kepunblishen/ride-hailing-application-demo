import SwiftUI

struct ServicesHubView: View {
    @EnvironmentObject private var tripSession: TripSession
    /// Opens Home destination search, optionally pre-selecting a ride tier.
    var onRequestRide: (_ preferredTierID: String?) -> Void

    @State private var showSchedule = false
    @State private var showCourier = false
    @State private var showGrocery = false
    @State private var showFood = false
    @State private var showHotel = false
    @State private var showHourly = false
    @State private var showGroupRide = false
    @State private var showTwoWheels = false
    @State private var showAirport = false
    @State private var showExecutive = false
    @State private var showConvenience = false
    @State private var showAlcohol = false
    @State private var showHealth = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    goAnywhereSection
                    deliverySection
                    if !tripSession.reservedTrips.isEmpty {
                        reservationsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("services.title"))
            .sheet(isPresented: $showSchedule) {
                ScheduleRideSheet()
            }
            .sheet(isPresented: $showCourier) {
                CourierProductSheet()
            }
            .sheet(isPresented: $showGrocery) {
                GroceryProductSheet()
            }
            .sheet(isPresented: $showFood) {
                FoodProductSheet()
            }
            .sheet(isPresented: $showHotel) {
                HotelTransferProductSheet()
            }
            .sheet(isPresented: $showHourly) {
                HourlyProductSheet()
            }
            .sheet(isPresented: $showGroupRide) {
                GroupRideProductSheet()
            }
            .sheet(isPresented: $showTwoWheels) {
                TwoWheelsProductSheet()
            }
            .sheet(isPresented: $showAirport) {
                AirportProductSheet()
            }
            .sheet(isPresented: $showExecutive) {
                ExecutiveProductSheet()
            }
            .sheet(isPresented: $showConvenience) {
                ConvenienceProductSheet()
            }
            .sheet(isPresented: $showAlcohol) {
                AlcoholProductSheet()
            }
            .sheet(isPresented: $showHealth) {
                HealthProductSheet()
            }
        }
    }

    // MARK: - Go anywhere

    private var goAnywhereSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L10n.t("services.go_anywhere"))

            HStack(spacing: 10) {
                largeTile(
                    title: L10n.t("services.rides"),
                    symbol: "car.fill",
                    tint: Color(red: 0.12, green: 0.14, blue: 0.18),
                    iconTint: VuumColor.brand
                ) {
                    onRequestRide("vuum")
                }

                if tripSession.isServiceAvailable(ServiceProductID.twoWheels) {
                    largeTile(
                        title: L10n.t("services.two_wheels"),
                        symbol: "bicycle",
                        tint: Color(red: 0.18, green: 0.42, blue: 0.55),
                        iconTint: .white
                    ) {
                        showTwoWheels = true
                    }
                }

                if tripSession.isServiceAvailable(ServiceProductID.airport)
                    || tripSession.zoneContext.isAirportArea {
                    largeTile(
                        title: "Airport",
                        symbol: "airplane",
                        tint: Color(red: 0.12, green: 0.28, blue: 0.42),
                        iconTint: .white
                    ) {
                        showAirport = true
                    }
                } else {
                    largeTile(
                        title: L10n.t("services.rental"),
                        symbol: "key.fill",
                        tint: Color(red: 0.35, green: 0.28, blue: 0.55),
                        iconTint: .white
                    ) {
                        showHourly = true
                    }
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                if tripSession.isServiceAvailable(ServiceProductID.comfort) {
                    smallTile(title: L10n.t("services.comfort"), symbol: "car.side.fill") {
                        onRequestRide("comfort")
                    }
                }
                if tripSession.isServiceAvailable(ServiceProductID.xxl) {
                    smallTile(title: L10n.t("services.xl"), symbol: "car.2.fill") {
                        onRequestRide("xl")
                    }
                }
                if tripSession.isServiceAvailable(ServiceProductID.executive) {
                    smallTile(title: L10n.t("services.executive"), symbol: "sparkles") {
                        showExecutive = true
                    }
                }
                if tripSession.isServiceAvailable(ServiceProductID.reserve) {
                    smallTile(title: L10n.t("services.reserve"), symbol: "calendar") {
                        showSchedule = true
                    }
                }
                NavigationLink {
                    BusinessProfileView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.brandInk)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    colors: [VuumColor.brand.opacity(0.35), VuumColor.brand.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )

                        Text(L10n.t("services.corporate"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                if tripSession.isServiceAvailable(ServiceProductID.hourly) {
                    smallTile(title: L10n.t("services.hourly"), symbol: "clock.fill") {
                        showHourly = true
                    }
                }
                smallTile(title: "Hotel", symbol: "building.2.fill") {
                    showHotel = true
                }
                if tripSession.isServiceAvailable(ServiceProductID.group) {
                    smallTile(title: L10n.t("services.group_ride"), symbol: "person.3.fill") {
                        showGroupRide = true
                    }
                }
            }
        }
    }

    // MARK: - Delivery

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(L10n.t("services.get_delivered"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ],
                spacing: 10
            ) {
                ForEach(Self.deliveryItems.filter { item in
                    item.id != "packages" || tripSession.isServiceAvailable(ServiceProductID.courier)
                }) { item in
                    deliveryTile(item) {
                        switch item.id {
                        case "packages": showCourier = true
                        case "grocery": showGrocery = true
                        case "food": showFood = true
                        case "convenience": showConvenience = true
                        case "alcohol": showAlcohol = true
                        case "health": showHealth = true
                        default: break
                        }
                    }
                }
            }
        }
    }

    private var reservationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(L10n.t("services.upcoming_reservations"))

            VStack(spacing: 0) {
                ForEach(Array(tripSession.reservedTrips.enumerated()), id: \.element.id) { index, trip in
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.brandInk)
                            .frame(width: 36, height: 36)
                            .background(VuumColor.brand.opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(trip.pickupName) → \(trip.dropoffName)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VuumColor.primaryText)
                            Text("\(trip.tierName) · \(trip.when.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 13))
                                .foregroundStyle(VuumColor.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < tripSession.reservedTrips.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Tiles

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(VuumColor.primaryText)
    }

    private func largeTile(
        title: String,
        symbol: String,
        tint: Color,
        iconTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconTint)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(title)
    }

    private func smallTile(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [VuumColor.brand.opacity(0.35), VuumColor.brand.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(title)
    }

    private func deliveryTile(_ item: DeliveryServiceItem, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(item.tileColor.opacity(0.22))
                            .frame(width: 48, height: 48)
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(item.tileColor)
                    }

                    Spacer(minLength: 0)

                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.86, green: 0.22, blue: 0.28), in: Capsule())
                    }
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(item.title)
    }

    private static let deliveryItems: [DeliveryServiceItem] = [
        .init(id: "food", title: "Food", symbol: "fork.knife", tileColor: Color(red: 0.95, green: 0.45, blue: 0.2), badge: "Promo"),
        .init(id: "grocery", title: "Grocery", symbol: "cart.fill", tileColor: Color(red: 0.2, green: 0.62, blue: 0.38), badge: "Promo"),
        .init(id: "convenience", title: "Convenience", symbol: "bag.fill", tileColor: Color(red: 0.25, green: 0.45, blue: 0.9), badge: nil),
        .init(id: "alcohol", title: "Alcohol", symbol: "wineglass.fill", tileColor: Color(red: 0.55, green: 0.25, blue: 0.55), badge: nil),
        .init(id: "health", title: "Health", symbol: "cross.case.fill", tileColor: Color(red: 0.2, green: 0.55, blue: 0.7), badge: "Promo"),
        .init(id: "packages", title: "Packages", symbol: "shippingbox.fill", tileColor: Color(red: 0.4, green: 0.35, blue: 0.3), badge: nil),
    ]
}

// MARK: - Models

private struct DeliveryServiceItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let tileColor: Color
    let badge: String?
}

