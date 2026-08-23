import SwiftUI

struct ServicesHubView: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.colorScheme) private var colorScheme
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
                VStack(alignment: .leading, spacing: VuumLayout.sectionSpacing) {
                    goAnywhereSection
                    deliverySection
                    if tripSession.reservedTrips.isEmpty {
                        emptyReservationsSection
                    } else {
                        reservationsSection
                    }
                }
                .padding(.horizontal, VuumLayout.pageInset)
                .padding(.top, 8)
                .padding(.bottom, VuumLayout.sectionSpacing)
            }
            .VuumGroupedBackground()
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
        VStack(alignment: .leading, spacing: VuumLayout.stackSpacing) {
            sectionHeader(L10n.t("services.go_anywhere"))

            HStack(spacing: VuumLayout.chipSpacing + 2) {
                largeTile(
                    title: L10n.t("services.rides"),
                    symbol: "car.fill"
                ) {
                    onRequestRide("vuum")
                }

                if tripSession.isServiceAvailable(ServiceProductID.twoWheels) {
                    largeTile(
                        title: L10n.t("services.two_wheels"),
                        symbol: "bicycle"
                    ) {
                        showTwoWheels = true
                    }
                }

                if tripSession.isServiceAvailable(ServiceProductID.airport)
                    || tripSession.zoneContext.isAirportArea {
                    largeTile(
                        title: "Airport",
                        symbol: "airplane"
                    ) {
                        showAirport = true
                    }
                } else {
                    largeTile(
                        title: L10n.t("services.rental"),
                        symbol: "key.fill"
                    ) {
                        showHourly = true
                    }
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: VuumLayout.chipSpacing + 2),
                    GridItem(.flexible(), spacing: VuumLayout.chipSpacing + 2),
                ],
                spacing: VuumLayout.chipSpacing + 2
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
                    rowTileLabel(title: L10n.t("services.corporate"), symbol: "briefcase.fill")
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
        VStack(alignment: .leading, spacing: VuumLayout.stackSpacing) {
            sectionHeader(L10n.t("services.get_delivered"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: VuumLayout.chipSpacing + 2),
                    GridItem(.flexible(), spacing: VuumLayout.chipSpacing + 2),
                ],
                spacing: VuumLayout.chipSpacing + 2
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

    private var emptyReservationsSection: some View {
        VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
            sectionHeader(L10n.t("services.upcoming_reservations"))

            Button {
                showSchedule = true
            } label: {
                VuumInlineEmptyRow(
                    systemImage: "calendar",
                    title: L10n.t("status.empty_upcoming_title"),
                    message: L10n.t("status.empty_upcoming_detail")
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    VuumColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                        .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.t("services.reserve"))
        }
    }

    private var reservationsSection: some View {
        VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
            sectionHeader(L10n.t("services.upcoming_reservations"))

            VStack(spacing: 0) {
                ForEach(Array(tripSession.reservedTrips.enumerated()), id: \.element.id) { index, trip in
                    HStack(spacing: VuumLayout.rowSpacing) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.brand)
                            .frame(width: 22, alignment: .center)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(trip.pickupName) → \(trip.dropoffName)")
                                .font(VuumType.bodySemibold)
                                .foregroundStyle(VuumColor.primaryText)
                            Text("\(trip.tierName) · \(trip.when.formatted(date: .abbreviated, time: .shortened))")
                                .font(VuumType.caption)
                                .foregroundStyle(VuumColor.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, VuumLayout.rowSpacing)

                    if index < tripSession.reservedTrips.count - 1 {
                        Divider()
                            .overlay(VuumColor.divider)
                            .padding(.leading, 48)
                    }
                }
            }
            .background(
                VuumColor.cardBackground,
                in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                    .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
            }
        }
    }

    // MARK: - Tiles

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VuumType.section)
            .foregroundStyle(VuumColor.primaryText)
    }

    private func largeTile(
        title: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 28, alignment: .leading)

                Text(title)
                    .font(VuumType.bodySemibold)
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                VuumColor.cardBackground,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(title)
    }

    private func smallTile(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowTileLabel(title: title, symbol: symbol)
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(title)
    }

    private func rowTileLabel(title: String, symbol: String) -> some View {
        HStack(spacing: VuumLayout.rowSpacing) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(VuumType.bodySemibold)
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, VuumLayout.rowSpacing)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(
            VuumColor.cardBackground,
            in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private func deliveryTile(_ item: DeliveryServiceItem, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
                HStack(alignment: .top) {
                    Image(systemName: item.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(VuumColor.brand)
                        .frame(width: 28, alignment: .leading)

                    Spacer(minLength: 0)

                    if let badge = item.badge {
                        VuumOfferBadge(title: badge, kind: .promo)
                    }
                }

                Text(item.title)
                    .font(VuumType.bodySemibold)
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                VuumColor.cardBackground,
                in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                    .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(VuumPressStyle())
        .accessibilityLabel(item.title)
    }

    private static let deliveryItems: [DeliveryServiceItem] = [
        .init(id: "food", title: "Food", symbol: "fork.knife", badge: "Promo"),
        .init(id: "grocery", title: "Grocery", symbol: "cart.fill", badge: "Promo"),
        .init(id: "convenience", title: "Convenience", symbol: "bag.fill", badge: nil),
        .init(id: "alcohol", title: "Alcohol", symbol: "wineglass.fill", badge: nil),
        .init(id: "health", title: "Health", symbol: "cross.case.fill", badge: "Promo"),
        .init(id: "packages", title: "Packages", symbol: "shippingbox.fill", badge: nil),
    ]
}

// MARK: - Models

private struct DeliveryServiceItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let badge: String?
}
