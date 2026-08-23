import SwiftUI

/// Choose-a-ride — full-bleed map + quiet bottom sheet of fare tiers.
/// Passenger / for-me stay on `ConfirmRideScaffoldView` after Confirm.
struct RideOptionsScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @Environment(\.colorScheme) private var colorScheme

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var confirmTitle: String {
        if let name = tripSession.selectedTier?.name {
            return String(format: L10n.Trip.confirmTier, name)
        }
        return L10n.Trip.chooseRide
    }

    var body: some View {
        GeometryReader { geo in
            let sheetCap = VuumLayout.mapSheetMaxHeight(in: geo.size.height)

            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .ignoresSafeArea()

                chooseRideSheet
                    .frame(maxHeight: sheetCap, alignment: .bottom)
            }
            .overlay(alignment: .topLeading) {
                VuumFlowBackChrome {
                    tripSession.changeDestination()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Sheet

    private var chooseRideSheet: some View {
        VuumSheetChrome(title: L10n.Trip.chooseRide, glassStyle: .quiet) {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: VuumLayout.rowSpacing) {
                        if let cancellation = tripSession.lastCancellation {
                            cancellationBanner(cancellation)
                        }

                        if tripSession.surgeState.isActive
                            || tripSession.zoneContext.surchargeMessage != nil {
                            surgeBanner
                        }

                        ForEach(tripSession.availableTiers) { tier in
                            tierCard(tier)
                        }
                    }
                    .padding(.bottom, 8)
                }

                VuumHairline()
                    .padding(.top, 8)

                stickyFooter
                    .padding(.top, 12)
            }
        }
    }

    // MARK: - Sticky footer (payment + confirm)

    private var stickyFooter: some View {
        VStack(spacing: 12) {
            PaymentMethodPickerRow()

            VuumPrimaryButton(
                title: confirmTitle,
                enabled: tripSession.selectedTier != nil
            ) {
                tripSession.proceedToConfirmRide()
            }
        }
    }

    // MARK: - Tier card

    private func tierCard(_ tier: RideTier) -> some View {
        let selected = tripSession.selectedTier?.id == tier.id
        let amounts = discountedAmounts(for: tier)
        let hasPromo = tripSession.appliedPromoDiscountCDF > 0
        let meta = tier.etaAndDropoffLabel(routeDistanceMeters: tripSession.tripRouteDistanceMeters)

        return Button {
            tripSession.chooseTier(tier)
        } label: {
            HStack(spacing: 14) {
                vehicleArt(for: tier, selected: selected)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tier.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .lineLimit(1)

                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(tier.capacity)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(VuumColor.secondaryText)
                        .accessibilityLabel("\(tier.capacity) seats")
                    }

                    Text(meta)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatPrice(cdf: amounts.cdf, usd: amounts.usd))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                        .multilineTextAlignment(.trailing)

                    if hasPromo {
                        Text(formatPrice(cdf: tier.priceCDF, usd: tier.priceUSD))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                            .strikethrough(true, color: VuumColor.secondaryText)
                    }
                }

                selectionRing(selected: selected)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                    .fill(selected ? VuumColor.chipBackground : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                    .strokeBorder(
                        selected ? VuumColor.brand : VuumColor.hairline(for: colorScheme),
                        lineWidth: selected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(tier.name), \(tier.capacity) seats, \(meta), \(formatPrice(cdf: amounts.cdf, usd: amounts.usd))"
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func vehicleArt(for tier: RideTier, selected: Bool) -> some View {
        Image(systemName: tier.productSystemImage)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(selected ? VuumColor.brand : VuumColor.primaryText)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 64, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VuumColor.chipBackground)
            )
            .accessibilityHidden(true)
    }

    private func selectionRing(selected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    selected ? VuumColor.brand : VuumColor.hairline(for: colorScheme),
                    lineWidth: 2
                )
                .frame(width: 22, height: 22)
            if selected {
                Circle()
                    .fill(VuumColor.brand)
                    .frame(width: 12, height: 12)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Banners

    private func cancellationBanner(_ cancellation: CancellationRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: cancellation.wasFree ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VuumColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(cancellation.summaryLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                if !cancellation.wasFree, cancellation.feeLocal > 0 {
                    Text("Fee \(AppLocale.formatPrimary(local: cancellation.feeLocal, market: market))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            Spacer(minLength: 8)
            Button {
                tripSession.dismissCancellationBanner()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var surgeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: tripSession.zoneContext.isAirportArea ? "airplane.departure" : "bolt.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VuumColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(surgeBannerTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Text(surgeBannerSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Spacer(minLength: 8)
            if tripSession.surgeState.isActive {
                Text(String(format: "%.2g×", tripSession.surgeState.multiplier))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VuumColor.brand.opacity(0.14), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(surgeBannerTitle). \(surgeBannerSubtitle)")
    }

    private var surgeBannerTitle: String {
        if tripSession.surgeState.isActive {
            let label = tripSession.surgeState.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { return label }
        }
        if let zone = tripSession.zoneContext.primaryZone {
            switch zone.kind {
            case .highDemand, .downtown:
                return zone.kind.displayTitle
            case .airport:
                return zone.name
            default:
                return zone.name
            }
        }
        return "High demand"
    }

    private var surgeBannerSubtitle: String {
        if let message = tripSession.zoneContext.surchargeMessage {
            return message
        }
        if tripSession.surgeState.isActive {
            return String(format: "%.2g× fare multiplier applied", tripSession.surgeState.multiplier)
        }
        return "Higher fares may apply in this area"
    }

    // MARK: - Currency

    private func discountedAmounts(for tier: RideTier) -> (cdf: Int, usd: Double) {
        let discount = tripSession.appliedPromoDiscountCDF
        let minimum = AppLocale.minimumFareLocal(for: market)
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
}
