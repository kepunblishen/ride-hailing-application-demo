import SwiftUI


/// Confirm step — passenger, payment, promo / prefs. Reached via `TripPhase.confirmingRide`.
struct ConfirmRideScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAdjustPickup = false
    @State private var showMoreOptions = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var selectedTierName: String {
        tripSession.selectedTier?.name ?? "ride"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .zIndex(0)

                VuumSheetChrome(title: L10n.Trip.confirmRide) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: VuumLayout.rowSpacing) {
                            if let tier = tripSession.selectedTier {
                                confirmRideSummary(tier)
                            }

                            forMeSwitcher

                            if tripSession.bookForSomeoneElse {
                                passengerFields
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            PaymentMethodPickerRow()

                            if let preview = tripSession.farePreview {
                                farePreviewCard(preview)
                            }

                            DisclosureGroup(isExpanded: $showMoreOptions) {
                                VStack(spacing: VuumLayout.rowSpacing) {
                                    fareNegotiationSection
                                    promoSection
                                    preferencesSection
                                    CorporateTripOptionsView()
                                }
                                .padding(.top, 8)
                            } label: {
                                Text("Promo, preferences & more")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                            }
                            .tint(VuumColor.brand)
                        }
                        .padding(.bottom, 4)
                        .animation(.easeInOut(duration: 0.2), value: tripSession.bookForSomeoneElse)
                    }
                    .frame(maxHeight: min(geo.size.height * 0.36, 280))

                    VuumHairline()
                        .padding(.vertical, 10)

                    VStack(spacing: VuumLayout.rowSpacing) {
                        VuumPrimaryButton(
                            title: tripSession.scheduleForLater == nil
                                ? "Confirm \(selectedTierName)"
                                : "Reserve \(selectedTierName)",
                            enabled: tripSession.canConfirmRequest
                        ) {
                            tripSession.confirmRequest()
                        }

                        Button("Change ride") {
                            tripSession.backToChoosingRide()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxHeight: VuumLayout.mapSheetMaxHeight(in: geo.size.height), alignment: .bottom)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            }
            .overlay(alignment: .topLeading) {
                VuumFlowBackChrome {
                    tripSession.backToChoosingRide()
                }
            }
        }
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
        }
        .alert(
            "Ride reserved",
            isPresented: Binding(
                get: { tripSession.reservationConfirmationMessage != nil },
                set: { if !$0 { tripSession.clearReservationConfirmation() } }
            )
        ) {
            Button("OK", role: .cancel) {
                tripSession.clearReservationConfirmation()
            }
        } message: {
            Text(tripSession.reservationConfirmationMessage ?? "")
        }
    }

    private func confirmRideSummary(_ tier: RideTier) -> some View {
        let amounts = discountedAmounts(for: tier)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: tier.productSystemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                    HStack(spacing: 8) {
                        RideClassETABadge(minutes: tier.classETABadgeMinutes, compact: true)
                        if let dropoff = tripSession.dropoff {
                            Text("To \(dropoff.name)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VuumColor.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 8)
                Text(formatPrice(cdf: amounts.cdf, usd: amounts.usd))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
            }

            HStack(spacing: VuumLayout.pageInset) {
                Button(L10n.Trip.adjustPickup) {
                    showAdjustPickup = true
                }
                Button(L10n.Trip.changeDestination) {
                    tripSession.changeDestination()
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(VuumColor.secondaryText)
        }
        .padding(14)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private var forMeSwitcher: some View {
        HStack(spacing: 0) {
            passengerModeChip(
                title: L10n.Trip.forMe,
                systemImage: "person.fill",
                selected: !tripSession.bookForSomeoneElse
            ) {
                tripSession.bookForSomeoneElse = false
            }
            passengerModeChip(
                title: L10n.Trip.forOthers,
                systemImage: "person.2.fill",
                selected: tripSession.bookForSomeoneElse
            ) {
                tripSession.bookForSomeoneElse = true
            }
        }
        .padding(3)
        .background(VuumColor.chipBackground, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
        }
    }

    private func passengerModeChip(
        title: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? VuumColor.accentOn : VuumColor.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(selected ? VuumColor.brand : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var passengerFields: some View {
        VStack(alignment: .leading, spacing: VuumLayout.chipSpacing) {
            TextField(L10n.Trip.passengerName, text: $tripSession.passengerName)
                .foregroundStyle(VuumColor.primaryText)
                .tint(VuumColor.brand)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    VuumDestinationSearchField.searchFill,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                )
            TextField(L10n.Trip.passengerPhone, text: $tripSession.passengerPhone)
                .keyboardType(.phonePad)
                .foregroundStyle(VuumColor.primaryText)
                .tint(VuumColor.brand)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    VuumDestinationSearchField.searchFill,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                )
            if !tripSession.canConfirmRequest {
                Text("Enter the passenger's name and phone to continue.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
    }

    private func farePreviewCard(_ fare: FareBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fare breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            farePreviewRow("Base fare", fare.baseFareCDF)
            farePreviewRow("Distance", fare.distanceFareCDF)
            farePreviewRow("Time", fare.timeFareCDF)
            if fare.waitingFareCDF > 0 {
                farePreviewRow("Waiting", fare.waitingFareCDF)
            }
            if fare.isSurgeActive {
                farePreviewRow(
                    String(format: "High demand · %.2g×", fare.surgeMultiplier),
                    fare.surgeFareCDF
                )
            }
            if fare.tollCDF > 0 {
                farePreviewRow("Airport / toll", fare.tollCDF)
            }
            if fare.serviceFeeCDF > 0 {
                farePreviewRow("Service fee", fare.serviceFeeCDF)
            }
            if fare.taxCDF > 0 {
                farePreviewRow(market == .kenya ? "Tax" : "TVA 16%", fare.taxCDF)
            }
            if fare.discountCDF > 0 {
                HStack {
                    Text("Promo")
                        .foregroundStyle(VuumColor.secondaryText)
                    Spacer()
                    Text(formatLocalDiscount(fare.discountCDF))
                        .fontWeight(.medium)
                        .foregroundStyle(VuumColor.brand)
                }
                .font(.system(size: 13))
            }
            if fare.minimumFareApplied {
                Text("Minimum fare applied")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            if let tier = tripSession.selectedTier {
                Text(TripEmissions.displayLabel(distanceKm: fare.distanceKm, vehicleClass: tier.vehicleClass))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            VuumHairline()
            HStack {
                Text("Estimated total")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                Text(formatPrice(cdf: fare.totalCDF, usd: fare.totalUSD))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
            }
        }
        .padding(14)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fareNegotiationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { tripSession.negotiateFareEnabled },
                set: { tripSession.setNegotiateFareEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggest a fare")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VuumColor.primaryText)
                    Text("Optional — driver may accept within ±15%")
                        .font(.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .tint(VuumColor.brand)

            if tripSession.negotiateFareEnabled, let target = tripSession.negotiatedTargetCDF {
                let step = market == .kenya ? 50 : 500
                Stepper {
                    Text(AppLocale.formatPrimary(local: target, market: market))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                } onIncrement: {
                    tripSession.setNegotiatedTargetCDF(target + step)
                } onDecrement: {
                    tripSession.setNegotiatedTargetCDF(target - step)
                }
            }
        }
        .padding(VuumLayout.rowSpacing)
        .background(
            VuumColor.chipBackground,
            in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
        )
    }

    private func farePreviewRow(_ title: String, _ amount: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(AppLocale.formatPrimary(local: amount, market: market))
                .fontWeight(.medium)
                .foregroundStyle(VuumColor.primaryText)
        }
        .font(.system(size: 13))
    }

    private var promoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("Promo code", text: $tripSession.promoCode)
                    .textInputAutocapitalization(.characters)
                    .foregroundStyle(VuumColor.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        VuumDestinationSearchField.searchFill,
                        in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                    )
                Button("Apply") {
                    tripSession.applyPromo()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
            }
            promoStatusLine
        }
    }

    @ViewBuilder
    private var promoStatusLine: some View {
        switch tripSession.promoStatus {
        case .applied(_, let discount, let title):
            HStack {
                Text("\(title) — \(formatLocalDiscount(discount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.brand)
                Spacer()
                Button("Remove") {
                    tripSession.clearPromo()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            }
        case .invalid:
            Text("This promo code isn't valid")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VuumColor.brand)
        case .expired:
            Text("This promo code has expired")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VuumColor.brand)
        case .notEligible(let reason):
            Text(reason)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VuumColor.brand)
        case .idle:
            EmptyView()
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ride preferences")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)

            Toggle(isOn: $tripSession.preferQuietRide) {
                Label("Quiet ride", systemImage: "speaker.slash.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
            }
            .tint(VuumColor.brand)

            TextField("Accessibility notes for your driver", text: $tripSession.accessibilityNotes, axis: .vertical)
                .lineLimit(2...4)
                .foregroundStyle(VuumColor.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    VuumDestinationSearchField.searchFill,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                )
        }
        .padding(VuumLayout.rowSpacing)
        .background(
            VuumColor.chipBackground,
            in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
        )
    }

    private func discountedAmounts(for tier: RideTier) -> (cdf: Int, usd: Double) {
        let discount = tripSession.appliedPromoDiscountCDF
        let minimum = AppLocale.minimumFareLocal
        guard discount > 0 else { return (tier.priceCDF, tier.priceUSD) }
        let cdf = max(tier.priceCDF - discount, minimum)
        let usd = tier.priceCDF > 0
            ? tier.priceUSD * (Double(cdf) / Double(tier.priceCDF))
            : tier.priceUSD
        return (cdf, usd)
    }

    private func formatPrice(cdf: Int, usd: Double) -> String {
        AppLocale.formatTierPrice(cdf: cdf, usd: usd, market: market)
    }

    private func formatLocalDiscount(_ amount: Int) -> String {
        "-\(Money.local(amount, market: market == .kenya ? .kenya : .drc).formatted)"
    }
}
