import SwiftUI

/// Driver matched / en-route / arrived (PIN) / in-trip — map-dominant compact sheet.
struct ActiveTripScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var location: RiderLocationManager
    @AppStorage("vuum.safety.requirePIN") private var requirePIN = true
    @State private var showSafety = false
    @State private var showChat = false
    @State private var showCancel = false
    @State private var showChangeDestination = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var canCancel: Bool {
        switch tripSession.phase {
        case .matched, .driverEnRoute, .driverArrived:
            return true
        default:
            return false
        }
    }

    private var showPickupPIN: Bool {
        switch tripSession.phase {
        case .matched, .driverEnRoute:
            return true
        default:
            return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TripMapLayer()

                    .zIndex(0)


                floatingChrome

                if let trip = tripSession.activeTrip {
                    VuumSheetChrome(title: nil) {
                        VStack(alignment: .leading, spacing: 14) {
                            alertStack(trip)

                            if tripSession.phase == .driverArrived {
                                pickupWaitBanner
                            }

                            statusHeader(trip)

                            VuumHairline()

                            EnRouteDriverIdentityRow(driver: trip.driver)

                            if tripSession.phase == .inTrip {
                                LiveTripProgressBar(fraction: tripSession.tripProgressFraction)
                            }

                            if tripSession.phase == .driverArrived {
                                BoardingPINPanel(
                                    tripPIN: trip.tripPIN,
                                    entry: $tripSession.boardingPINEntry,
                                    rejected: tripSession.boardingPINRejected,
                                    requirePIN: requirePIN,
                                    onConfirm: { tripSession.confirmBoarding() }
                                )
                                .onChange(of: tripSession.boardingPINEntry) { _, _ in
                                    if tripSession.boardingPINRejected {
                                        tripSession.boardingPINRejected = false
                                    }
                                }
                            }

                            callMessageRow

                            if tripSession.canChangeInTripDestination {
                                Button {
                                    showChangeDestination = true
                                } label: {
                                    Label("Change destination", systemImage: "mappin.and.ellipse")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(VuumColor.brand)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .frame(maxHeight: sheetMaxHeight(for: geo.size.height), alignment: .bottom)
                }
            }
        }
        .sheet(isPresented: $showSafety) {
            SafetyToolkitView()
        }
        .sheet(isPresented: $showChat) {
            DriverChatView()
        }
        .sheet(isPresented: $showCancel) {
            CancelTripSheet(
                title: "Cancel trip?",
                isFree: tripSession.isCancellationFree,
                feeLocal: tripSession.cancellationFeeLocal,
                market: market
            ) { reason in
                tripSession.cancelActiveTrip(reason: reason)
            }
        }
        .sheet(isPresented: $showChangeDestination) {
            ChangeDestinationSheet()
        }
        .task {
            location.startUpdatingIfAllowed()
            await permissions.refreshStatuses()
            tripSession.audioRecorder.refreshPermissionState()
        }
    }

    private func sheetMaxHeight(for height: CGFloat) -> CGFloat {
        // Keep map visible: clamp to shared map-sheet tokens (~40—55%).
        let fraction: CGFloat
        switch tripSession.phase {
        case .driverArrived:
            fraction = VuumLayout.mapSheetMaxFraction
        case .inTrip:
            fraction = VuumLayout.mapSheetPreferredFraction
        default:
            fraction = VuumLayout.mapSheetMinFraction
        }
        return VuumLayout.mapSheetMaxHeight(in: height, fraction: fraction)
    }

    // MARK: - Floating chrome

    private var floatingChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if canCancel {
                    Button {
                        showCancel = true
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .frame(width: 48, height: 48)
                            .VuumChromeMaterialBackground(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    .accessibilityHint("Opens cancel trip")
                }

                Spacer(minLength: 0)

                Button {
                    showSafety = true
                } label: {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tripSession.sosRequested ? VuumColor.danger : VuumColor.primaryText)
                        .frame(width: 48, height: 48)
                        .VuumChromeMaterialBackground(in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Safety")
                .accessibilityHint("Opens safety tools, share trip, and SOS")
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Alerts (only when active)

    @ViewBuilder
    private func alertStack(_ trip: ActiveTrip) -> some View {
        if tripSession.sosRequested {
            sosBanner
        }
        if tripSession.isRecordingTripAudio {
            recordingBanner
        }
        if let autoNotice = tripSession.automaticSafetyNotice {
            noticeBanner(autoNotice)
        }
        if let notice = tripSession.destinationChangeNotice {
            noticeBanner(notice)
        }
        if let deviation = tripSession.routeDeviationNotice {
            routeDeviationBanner(text: deviation, trip: trip)
        }
        if tripSession.isRecalculatingTripRoute {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(VuumColor.brand)
                Text("Updating route & fare…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
    }

    // MARK: - Status

    private func statusHeader(_ trip: ActiveTrip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(statusTitle(for: trip))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if showPickupPIN {
                    pickupPINChip(trip.tripPIN)
                } else if tripSession.phase == .driverArrived {
                    Label("Share PIN with your driver", systemImage: "lock.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                } else if let detail = trip.statusDetail.nilIfBlank {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if tripSession.phase == .driverArrived {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(VuumColor.brand)
                    Text("Here")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                        .textCase(.uppercase)
                }
            } else {
                LiveETABadge(
                    minutes: trip.etaMinutes,
                    caption: tripSession.phase == .inTrip ? "left" : "MIN",
                    emphasize: true,
                    includeUnitInValue: tripSession.phase == .inTrip
                )
            }
        }
    }

    private func statusTitle(for trip: ActiveTrip) -> String {
        let mins = max(trip.etaMinutes, 0)
        switch tripSession.phase {
        case .matched:
            return mins > 0
                ? "Driver arriving in \(TripGeo.formatDuration(minutes: mins))"
                : trip.statusHeadline
        case .driverEnRoute:
            return mins > 0
                ? "Driver arriving in \(TripGeo.formatDuration(minutes: mins))"
                : trip.statusHeadline
        case .driverArrived:
            return "Driver has arrived"
        case .inTrip:
            return mins > 0
                ? "Arriving in \(TripGeo.formatDuration(minutes: mins))"
                : trip.statusHeadline
        default:
            return trip.statusHeadline
        }
    }

    private func pickupPINChip(_ pin: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            Text("Pickup PIN:")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            Text(pin)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(VuumColor.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pickup PIN \(pin)")
    }

    // MARK: - Actions

    private var callMessageRow: some View {
        HStack(spacing: 12) {
            Button {
                tripSession.callDriver()
            } label: {
                Label("Call", systemImage: "phone.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        VuumColor.chipBackground,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Places a phone call to your driver")

            Button {
                guard tripSession.isChatAvailable else { return }
                showChat = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Label("Message", systemImage: "bubble.left.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.accentOn)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            tripSession.isChatAvailable
                                ? VuumColor.emphasizedFill
                                : VuumColor.emphasizedFill.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

                    if tripSession.isChatAvailable, tripSession.unreadChatCount > 0 {
                        Text(tripSession.unreadChatCount > 9 ? "9+" : "\(tripSession.unreadChatCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VuumColor.accentOn)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VuumColor.danger, in: Capsule())
                            .offset(x: -6, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!tripSession.isChatAvailable)
            .accessibilityHint(
                tripSession.isChatAvailable
                    ? "Opens chat with your driver"
                    : "Chat available once a driver is assigned"
            )
        }
    }

    // MARK: - Banners

    private var sosBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(VuumColor.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergency help requested")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
                Text("Vuum Safety is contacting you. Stay on the line if they call.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VuumColor.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recordingBanner: some View {
        Text("Recording trip audio — your driver is notified")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VuumColor.brand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(VuumColor.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func noticeBanner(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VuumColor.brand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(VuumColor.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func routeDeviationBanner(text: String, trip: ActiveTrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    tripSession.dismissRouteDeviationNotice()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VuumColor.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            ShareLink(
                item: TripShare.message(for: trip, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                subject: Text(L10n.Safety.shareSubject),
                message: Text(L10n.Safety.shareMessage)
            ) {
                Label(L10n.Safety.shareTrip, systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VuumColor.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var pickupWaitBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "timer")
                .foregroundStyle(VuumColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Driver waiting")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
                if tripSession.pickupWaitGraceRemaining > 0 {
                    Text("Free wait — \(tripSession.pickupWaitGraceRemaining)s left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                } else {
                    Text(
                        "Wait time — \(AppLocale.formatPrimary(local: tripSession.pickupWaitChargeLocal, market: market))"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Driver identity (en-route sheet)

/// Compact driver + vehicle row matching the en-route sheet layout.
struct EnRouteDriverIdentityRow: View {
    let driver: DriverProfile

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DriverAvatarView(driver: driver, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(driver.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(String(format: "%.1f", driver.rating))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VuumColor.brand)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(VuumColor.chipBackground, in: Capsule(style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: "Rated %.1f", driver.rating))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text(driver.plate)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(VuumColor.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(VuumColor.sheetBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(VuumColor.divider, lineWidth: 2)
                    )
                    .accessibilityLabel("License plate \(driver.plate)")

                Text(vehicleCaption)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var vehicleCaption: String {
        if let colour = driver.vehicleColour {
            return "\(driver.vehicleMakeModel), \(colour)"
        }
        return driver.vehicleMakeModel
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
