import SwiftUI

/// Driver matched / en-route / arrived (PIN) / in-trip — map stays dominant.
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
    @State private var confirmSOS = false
    @State private var showMicConsent = false

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

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TripMapLayer()

                topChrome

                VuumSheetChrome(title: nil) {
                    if let trip = tripSession.activeTrip {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 12) {
                                if tripSession.sosRequested {
                                    sosBanner
                                }

                                if tripSession.isRecordingTripAudio {
                                    recordingBanner
                                }

                                if let autoNotice = tripSession.automaticSafetyNotice {
                                    Text(autoNotice)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(VuumColor.brandInk)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(VuumColor.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }

                                if let notice = tripSession.destinationChangeNotice {
                                    Text(notice)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(VuumColor.brandInk)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(VuumColor.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

                                if tripSession.phase == .driverArrived {
                                    pickupWaitBanner
                                }

                                statusHeader(trip)

                                if tripSession.phase == .inTrip {
                                    LiveTripProgressBar(fraction: tripSession.tripProgressFraction)
                                }

                                // Header owns live ETA; card stays identity-only on the map overlay.
                                LiveDriverCard(
                                    driver: trip.driver,
                                    showPIN: (tripSession.phase == .matched || tripSession.phase == .driverEnRoute)
                                        ? trip.tripPIN
                                        : nil,
                                    etaMinutes: nil,
                                    passengerName: trip.passengerName,
                                    compact: true
                                )

                                if tripSession.phase == .driverEnRoute || tripSession.phase == .inTrip,
                                   tripSession.driverSpeedKmh > 0 {
                                    HStack {
                                        Label("Driver speed", systemImage: "gauge.with.dots.needle.33percent")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(VuumColor.secondaryText)
                                        Spacer()
                                        Text("\(tripSession.driverSpeedKmh) km/h")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(VuumColor.primaryText)
                                            .monospacedDigit()
                                    }
                                    .padding(.horizontal, 4)
                                    .accessibilityElement(children: .combine)
                                }

                                fareRow(trip)

                                if !trip.stops.isEmpty {
                                    stopsRow(trip)
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

                                actionRow(trip)

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

                                if tripSession.canRecordTripAudio
                                    || tripSession.isRecordingTripAudio
                                    || permissions.microphoneDenied
                                    || tripSession.audioRecorder.permissionDenied {
                                    audioControls
                                }

                                if canCancel {
                                    Button("Cancel trip") {
                                        showCancel = true
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 2)
                                }
                            }
                        }
                        .frame(maxHeight: min(geo.size.height * 0.52, 440))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .confirmationDialog(
            "Request emergency help?",
            isPresented: $confirmSOS,
            titleVisibility: .visible
        ) {
            Button("Request help now", role: .destructive) {
                tripSession.requestSOS(coordinate: location.latestLocation?.coordinate)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Vuum Safety will be notified with your trip details and will try to reach you immediately.")
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
        .alert("Safety recording", isPresented: $showMicConsent) {
            Button("Continue") {
                tripSession.toggleTripAudioRecording(using: permissions)
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Safety recording is available only during an active trip. Your driver is notified while recording is on.")
        }
        .task {
            location.startUpdatingIfAllowed()
            await permissions.refreshStatuses()
            tripSession.audioRecorder.refreshPermissionState()
        }
    }

    // MARK: - Top chrome

    private var topChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let trip = tripSession.activeTrip {
                    ShareLink(
                        item: TripShare.message(for: trip, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                        subject: Text("My Vuum trip"),
                        message: Text("Follow my live trip on Vuum")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Share trip")
                }

                Spacer()

                LiveTripSOSButton(helpSent: tripSession.sosRequested) {
                    if tripSession.sosRequested {
                        showSafety = true
                    } else {
                        confirmSOS = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Sections

    private var sosBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Emergency help requested")
                    .font(.system(size: 14, weight: .bold))
                Text("Vuum Safety is contacting you. Stay on the line if they call.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recordingBanner: some View {
        Text("Recording trip audio · your driver is notified")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VuumColor.brand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(VuumColor.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func routeDeviationBanner(text: String, trip: ActiveTrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
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
                if tripSession.pickupWaitGraceRemaining > 0 {
                    Text("Free wait · \(tripSession.pickupWaitGraceRemaining)s left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                } else {
                    Text(
                        "Wait time · \(AppLocale.formatPrimary(local: tripSession.pickupWaitChargeLocal, market: market))"
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

    private func statusHeader(_ trip: ActiveTrip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.statusHeadline)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                Text(trip.statusDetail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                if let passenger = trip.passengerName {
                    Text("Passenger · \(passenger)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
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
                    caption: tripSession.phase == .inTrip ? "left" : "ETA"
                )
            }
        }
    }

    private func fareRow(_ trip: ActiveTrip) -> some View {
        HStack {
            Label(trip.tier.name, systemImage: trip.tier.systemImage)
            Spacer()
            Label(trip.paymentMethod.title, systemImage: trip.paymentMethod.systemImage)
            Spacer()
            Text(
                AppLocale.formatFareTotal(
                    cdf: trip.fare.totalCDF,
                    usd: trip.fare.totalUSD,
                    market: market
                )
            )
            .fontWeight(.semibold)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(VuumColor.primaryText)
    }

    private func stopsRow(_ trip: ActiveTrip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.stops.count == 1 ? "1 stop" : "\(trip.stops.count) stops")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            Text(trip.stops.map(\.name).joined(separator: " · "))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func actionRow(_ trip: ActiveTrip) -> some View {
        HStack(spacing: 4) {
            LiveTripActionChip(
                title: "Safety",
                systemImage: "shield.lefthalf.filled"
            ) {
                showSafety = true
            }
            .accessibilityHint("Opens safety tools and SOS status")

            LiveTripActionChip(
                title: "Chat",
                systemImage: "bubble.left.and.bubble.right.fill",
                badge: tripSession.isChatAvailable ? tripSession.unreadChatCount : 0,
                tint: tripSession.isChatAvailable ? VuumColor.primaryText : VuumColor.secondaryText
            ) {
                guard tripSession.isChatAvailable else { return }
                showChat = true
            }
            .disabled(!tripSession.isChatAvailable)
            .accessibilityHint(
                tripSession.isChatAvailable
                    ? "Opens chat with your driver"
                    : "Chat available once a driver is assigned"
            )

            LiveTripActionChip(
                title: "Call",
                systemImage: "phone.fill"
            ) {
                tripSession.callDriver()
            }
            .accessibilityHint("Places a phone call to your driver")

            ShareLink(
                item: TripShare.message(for: trip, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                subject: Text("My Vuum trip"),
                message: Text("Follow my live trip on Vuum")
            ) {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(VuumColor.chipBackground, in: Circle())
                    Text("Share")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(VuumColor.primaryText)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share trip")
            .accessibilityHint("Shares a live trip link")
        }
    }

    private var audioControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if permissions.microphoneDenied || tripSession.audioRecorder.permissionDenied {
                Label("Safety recording unavailable", systemImage: "mic.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
                Text("Enable Microphone for Vuum in Settings to record trip audio during a ride.")
                    .font(.system(size: 11))
                    .foregroundStyle(VuumColor.secondaryText)
                Button("Open Settings") {
                    _ = permissions.openSystemSettings()
                }
                .font(.system(size: 13, weight: .semibold))
            } else {
                Button {
                    if tripSession.isRecordingTripAudio {
                        tripSession.toggleTripAudioRecording(using: permissions)
                    } else {
                        tripSession.audioRecorder.refreshPermissionState()
                        if tripSession.audioRecorder.permissionState == .undetermined
                            && !permissions.microphoneAuthorized {
                            showMicConsent = true
                        } else {
                            tripSession.toggleTripAudioRecording(using: permissions)
                        }
                    }
                } label: {
                    Label(
                        tripSession.isRecordingTripAudio ? "Stop recording" : "Record audio",
                        systemImage: tripSession.isRecordingTripAudio ? "stop.circle.fill" : "mic.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        tripSession.isRecordingTripAudio
                            ? Color.red.opacity(0.12)
                            : VuumColor.chipBackground,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tripSession.isRecordingTripAudio ? Color.red : VuumColor.primaryText)

                if let message = tripSession.audioRecorder.lastErrorMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                } else {
                    Text("Audio stays on this device. Your driver is notified while recording is on.")
                        .font(.system(size: 11))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
    }
}

