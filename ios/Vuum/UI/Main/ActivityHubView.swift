import SwiftUI

// MARK: - Filters

private enum ActivitySegment: String, CaseIterable, Identifiable {
    case all
    case completed
    case cancelled
    case upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .upcoming: return "Upcoming"
        }
    }
}

private enum ActivityTimeFilter: String, CaseIterable, Identifiable {
    case all
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All time"
        case .week: return "This week"
        case .month: return "This month"
        }
    }

    func includes(_ date: Date, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        switch self {
        case .all:
            return true
        case .week:
            guard let start = cal.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= start
        case .month:
            guard let start = cal.date(byAdding: .day, value: -30, to: now) else { return true }
            return date >= start
        }
    }
}

// MARK: - Hub

struct ActivityHubView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore

    @State private var segment: ActivitySegment = .all
    @State private var timeFilter: ActivityTimeFilter = .all
    @State private var productFilter: String = "All"
    @State private var helpReceipt: TripReceipt?
    @State private var shareText: String?

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var productOptions: [String] {
        let tiers = Set(tripSession.tripHistory.map(\.tierName))
            .union(tripSession.reservedTrips.map(\.tierName))
        return ["All"] + tiers.sorted()
    }

    private var filteredHistory: [TripReceipt] {
        tripSession.tripHistory.filter { receipt in
            timeFilter.includes(receipt.date)
                && (productFilter == "All" || receipt.tierName == productFilter)
                && statusMatches(receipt.status)
        }
    }

    private var filteredReservations: [ReservedTrip] {
        tripSession.reservedTrips.filter { trip in
            timeFilter.includes(trip.when)
                && (productFilter == "All" || trip.tierName == productFilter)
        }
        .sorted { $0.when < $1.when }
    }

    private func statusMatches(_ status: TripReceiptStatus) -> Bool {
        switch segment {
        case .all, .upcoming:
            return true
        case .completed:
            return status == .completed
        case .cancelled:
            return status == .cancelled
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChrome
                VuumHubLoadContainer {
                    content
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("activity.title"))
            .navigationDestination(for: TripReceipt.self) { receipt in
                ActivityReceiptDetailView(
                    receipt: receipt,
                    market: market,
                    onRebook: {
                        tripSession.rebookFromReceipt(receipt)
                        MainTabNavigation.openHome()
                    },
                    onHelp: { helpReceipt = receipt },
                    onShare: { shareText = receiptShareText(receipt) }
                )
            }
            .sheet(item: $helpReceipt) { receipt in
                TripHelpSheet(receipt: receipt)
            }
            .sheet(isPresented: Binding(
                get: { shareText != nil },
                set: { if !$0 { shareText = nil } }
            )) {
                if let shareText {
                    VuumActivityView(activityItems: [shareText])
                }
            }
            .onAppear {
                tripSession.refreshReservationStatuses()
                if segment == .all || segment == .completed {
                    if tripSession.tripHistory.isEmpty, !tripSession.reservedTrips.isEmpty {
                        segment = .upcoming
                    }
                }
            }
        }
    }

    // MARK: Chrome

    private var filterChrome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Activity", selection: $segment) {
                ForEach(ActivitySegment.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityTimeFilter.allCases) { filter in
                        filterChip(
                            title: filter.title,
                            selected: timeFilter == filter
                        ) {
                            timeFilter = filter
                        }
                    }

                    if productOptions.count > 1 {
                        Menu {
                            ForEach(productOptions, id: \.self) { option in
                                Button(option) { productFilter = option }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(productFilter == "All" ? "Product" : productFilter)
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(productFilter == "All" ? VuumColor.primaryText : VuumColor.brandInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                productFilter == "All" ? VuumColor.chipBackground : VuumColor.brand.opacity(0.35),
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(VuumColor.pageBackground)
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? VuumColor.brandInk : VuumColor.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selected ? VuumColor.brand.opacity(0.9) : VuumColor.chipBackground,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch segment {
        case .upcoming:
            upcomingContent
        case .all:
            combinedContent
        case .completed, .cancelled:
            pastContent
        }
    }

    @ViewBuilder
    private var pastContent: some View {
        if filteredHistory.isEmpty {
            emptyState(
                title: tripSession.tripHistory.isEmpty
                    ? L10n.t("activity.empty_title")
                    : "No trips match",
                systemImage: segment == .cancelled ? "xmark.circle" : "clock",
                message: tripSession.tripHistory.isEmpty
                    ? L10n.t("activity.empty_detail")
                    : "Try a different time range or product filter."
            )
        } else {
            List {
                Section {
                    ForEach(filteredHistory) { receipt in
                        NavigationLink(value: receipt) {
                            PastTripRow(receipt: receipt, market: market)
                        }
                    }
                } header: {
                    Text("\(filteredHistory.count) trip\(filteredHistory.count == 1 ? "" : "s")")
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var upcomingContent: some View {
        if filteredReservations.isEmpty {
            emptyState(
                title: tripSession.reservedTrips.isEmpty ? "No upcoming rides" : "No reservations match",
                systemImage: "calendar",
                message: tripSession.reservedTrips.isEmpty
                    ? "Reserved pickups will show here. Schedule a ride from Services."
                    : "Try a different time range or product filter."
            )
        } else {
            List {
                    Section {
                        ForEach(filteredReservations) { trip in
                            NavigationLink {
                                ReservedTripDetailView(trip: trip, market: market)
                            } label: {
                                UpcomingTripRow(trip: trip, market: market)
                            }
                        }
                    } header: {
                        Text("\(filteredReservations.count) reserved")
                    }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private var combinedContent: some View {
        if filteredHistory.isEmpty, filteredReservations.isEmpty {
            emptyState(
                title: L10n.t("activity.empty_title"),
                systemImage: "clock",
                message: L10n.t("activity.empty_detail")
            )
        } else {
            List {
                if !filteredReservations.isEmpty {
                    Section("Upcoming") {
                        ForEach(filteredReservations) { trip in
                            NavigationLink {
                                ReservedTripDetailView(trip: trip, market: market)
                            } label: {
                                UpcomingTripRow(trip: trip, market: market)
                            }
                        }
                    }
                }
                if !filteredHistory.isEmpty {
                    Section("Past") {
                        ForEach(filteredHistory) { receipt in
                            NavigationLink(value: receipt) {
                                PastTripRow(receipt: receipt, market: market)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func emptyState(title: String, systemImage: String, message: String) -> some View {
        let showBook = tripSession.tripHistory.isEmpty && segment == .past
        let showServices = tripSession.reservedTrips.isEmpty && segment == .upcoming
        return VuumEmptyStateView(
            systemImage: systemImage,
            title: title,
            message: message,
            actionTitle: showBook || showServices ? L10n.t("status.empty_trips_action") : nil,
            action: {
                if showBook {
                    MainTabNavigation.openHome(beginBooking: true)
                } else if showServices {
                    MainTabNavigation.openServices()
                }
            }
        )
    }

    private func receiptShareText(_ receipt: TripReceipt) -> String {
        let total = AppLocale.formatFareTotal(
            cdf: receipt.chargedTotalCDF,
            usd: receipt.chargedTotalUSD,
            market: market
        )
        var lines = [
            "Vuum trip receipt",
            "Receipt ID · \(String(receipt.id.prefix(8)).uppercased())",
            receipt.date.formatted(date: .complete, time: .shortened),
            "Status: \(receipt.status.title)",
            "From: \(receipt.pickupName)",
            "To: \(receipt.dropoffName)",
        ]
        if !receipt.stopNames.isEmpty {
            lines.append("Stops: \(receipt.stopNames.joined(separator: ", "))")
        }
        lines.append(contentsOf: [
            "Driver: \(receipt.driverName)",
            "Vehicle: \(receipt.vehicleLabel.isEmpty ? "—" : receipt.vehicleLabel)",
            "Product: \(receipt.tierName)",
            "Payment: \(receipt.paymentMethod.title)",
            "Distance: \(String(format: "%.1f km", receipt.fare.distanceKm))",
            "Duration: \(TripGeo.formatDuration(minutes: receipt.fare.durationMinutes))",
            "Total: \(total)",
        ])
        return lines.joined(separator: "\n")
    }
}

// MARK: - Rows

private struct PastTripRow: View {
    let receipt: TripReceipt
    let market: AppLocale.Market

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: receipt.status == .cancelled ? "xmark.circle.fill" : "car.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(receipt.status == .cancelled ? Color.secondary : VuumColor.brandInk)
                .frame(width: 40, height: 40)
                .background(
                    (receipt.status == .cancelled ? Color.secondary.opacity(0.15) : VuumColor.brand.opacity(0.22)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(receipt.dropoffName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    Spacer(minLength: 8)
                    Text(receipt.status.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(receipt.status == .cancelled ? Color.secondary : VuumColor.brandInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (receipt.status == .cancelled ? Color.secondary.opacity(0.12) : VuumColor.brand.opacity(0.25)),
                            in: Capsule()
                        )
                }
                Text("\(receipt.pickupName) · \(receipt.tierName)")
                    .font(.system(size: 13))
                    .foregroundStyle(VuumColor.secondaryText)
                    .lineLimit(1)
                if !receipt.vehicleLabel.isEmpty {
                    Text("\(receipt.driverName) · \(receipt.vehicleLabel)")
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                } else {
                    Text(receipt.driverName)
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                HStack {
                    Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                    Spacer()
                    if receipt.status == .cancelled {
                        Text("No charge")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                    } else {
                        Text(
                            AppLocale.formatFareTotal(
                                cdf: receipt.chargedTotalCDF,
                                usd: receipt.chargedTotalUSD,
                                market: market
                            )
                        )
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    }
                }
                HStack(spacing: 8) {
                    Label(receipt.paymentMethod.title, systemImage: receipt.paymentMethod.systemImage)
                    if let rating = receipt.rating {
                        Label("\(rating)", systemImage: "star.fill")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.dropoffName), \(receipt.status.title), \(receipt.date.formatted(date: .abbreviated, time: .shortened))")
    }
}

private struct UpcomingTripRow: View {
    let trip: ReservedTrip
    let market: AppLocale.Market
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: trip.status == .driverAssigned ? "car.fill" : "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 40, height: 40)
                    .background(VuumColor.brand.opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(trip.pickupName) → \(trip.dropoffName)")
                        .font(.system(size: 16, weight: .semibold))
                    Text(trip.when.formatted(date: .complete, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                    Text("\(trip.tierName) · \(AppLocale.formatFareTotal(cdf: trip.priceCDF, usd: trip.priceUSD, market: market))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(trip.statusDetailLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.brandInk)
                    if !trip.stopNames.isEmpty {
                        Text("Stops: \(trip.stopNames.joined(separator: ", "))")
                            .font(.system(size: 12))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    if let prefs = trip.preferences.summaryLine {
                        Text(prefs)
                            .font(.system(size: 12))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    Text("Conf · \(trip.confirmationCode)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }

            if let onCancel {
                Button("Cancel reservation", role: .destructive, action: onCancel)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.vertical, 6)
    }
}

struct ReservedTripDetailView: View {
    @EnvironmentObject private var tripSession: TripSession
    let trip: ReservedTrip
    let market: AppLocale.Market

    @State private var editDate: Date
    @State private var showCancelConfirm = false

    init(trip: ReservedTrip, market: AppLocale.Market) {
        self.trip = trip
        self.market = market
        _editDate = State(initialValue: trip.when)
    }

    private var liveTrip: ReservedTrip {
        tripSession.reservedTrips.first(where: { $0.id == trip.id }) ?? trip
    }

    var body: some View {
        List {
            Section("Reservation") {
                LabeledContent("Confirmation", value: liveTrip.confirmationCode)
                LabeledContent("Status", value: liveTrip.status.title)
                LabeledContent("Pickup", value: liveTrip.pickupName)
                LabeledContent("Drop-off", value: liveTrip.dropoffName)
                if !liveTrip.stopNames.isEmpty {
                    LabeledContent("Stops", value: liveTrip.stopNames.joined(separator: ", "))
                }
                LabeledContent("Product", value: liveTrip.tierName)
                LabeledContent(
                    "Fare",
                    value: AppLocale.formatFareTotal(
                        cdf: liveTrip.priceCDF,
                        usd: liveTrip.priceUSD,
                        market: market
                    )
                )
                LabeledContent("Payment", value: liveTrip.paymentMethod.title)
                if let passenger = liveTrip.passengerName {
                    LabeledContent("Passenger", value: passenger)
                }
                if let promo = liveTrip.promoCode {
                    LabeledContent("Promo", value: promo)
                }
            }

            if liveTrip.status == .driverAssigned {
                Section("Assigned driver") {
                    LabeledContent("Driver", value: liveTrip.assignedDriverName ?? "—")
                    if let vehicle = liveTrip.assignedVehicle {
                        LabeledContent("Vehicle", value: vehicle)
                    }
                    if let plate = liveTrip.assignedPlate {
                        LabeledContent("Plate", value: plate)
                    }
                }
            }

            if liveTrip.preferences.hasContent {
                Section("Preferences") {
                    if liveTrip.preferences.quietRide {
                        Label("Quiet ride", systemImage: "speaker.slash.fill")
                    }
                    let notes = liveTrip.preferences.accessibilityNotes
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !notes.isEmpty {
                        Text(notes)
                    }
                }
            }

            Section("Edit pickup time") {
                DatePicker(
                    "Pickup",
                    selection: $editDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                Button("Save new time") {
                    tripSession.updateReservationTime(liveTrip, to: editDate)
                }
                .font(.system(size: 16, weight: .semibold))
                Toggle(
                    "Remind me before pickup",
                    isOn: Binding(
                        get: { liveTrip.reminderEnabled },
                        set: { tripSession.setReservationReminder(liveTrip, enabled: $0) }
                    )
                )
            }

            Section {
                Button("Cancel reservation", role: .destructive) {
                    showCancelConfirm = true
                }
            } footer: {
                Text(liveTrip.statusDetailLine)
            }
        }
        .navigationTitle("Upcoming ride")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Cancel this reservation?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel reservation", role: .destructive) {
                tripSession.cancelReservation(liveTrip)
            }
            Button("Keep reservation", role: .cancel) {}
        }
    }
}

// MARK: - Receipt detail (PDF-like)

struct ActivityReceiptDetailView: View {
    let receipt: TripReceipt
    let market: AppLocale.Market
    let onRebook: () -> Void
    let onHelp: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                receiptCard

                VStack(spacing: 10) {
                    if receipt.status == .completed {
                        VuumPrimaryButton(title: "Rebook this trip", action: onRebook)
                    }
                    Button(action: onHelp) {
                        Label("Get help with this trip", systemImage: "questionmark.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(VuumColor.primaryText)
                            .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button(action: onShare) {
                        Label("Share receipt", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("VUUM")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(VuumColor.brandInk)
                Spacer()
                Text(receipt.status.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(VuumColor.chipBackground, in: Capsule())
            }
            .padding(.bottom, 16)

            Text(receipt.date.formatted(date: .complete, time: .shortened))
                .font(.system(size: 13))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.bottom, 18)

            routeBlock(title: "From", value: receipt.pickupName)
            if !receipt.stopNames.isEmpty {
                Divider().padding(.vertical, 12)
                routeBlock(title: "Stops", value: receipt.stopNames.joined(separator: " → "))
            }
            Divider().padding(.vertical, 12)
            routeBlock(title: "To", value: receipt.dropoffName)
            Divider().padding(.vertical, 12)

            metaRow("Driver", receipt.driverName)
            if !receipt.vehicleLabel.isEmpty {
                metaRow("Vehicle", receipt.vehicleLabel)
            }
            metaRow("Product", receipt.tierName)
            metaRow("Payment", receipt.paymentMethod.title)
            if let rating = receipt.rating {
                metaRow("Your rating", "\(rating) / 5")
            }
            if !receipt.feedbackTags.isEmpty {
                metaRow("Feedback", receipt.feedbackTags.joined(separator: " · "))
            }
            if let note = receipt.feedbackNote, !note.isEmpty {
                metaRow("Comment", note)
            }
            if let reason = receipt.cancelReason, !reason.isEmpty {
                metaRow("Cancel reason", reason)
            }
            metaRow("Distance", String(format: "%.1f km", receipt.fare.distanceKm))
            metaRow("Duration", TripGeo.formatDuration(minutes: receipt.fare.durationMinutes))

            Divider().padding(.vertical, 14)

            Text("Fare breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.bottom, 8)

            fareLine("Base fare", receipt.fare.baseFareCDF, nil)
            fareLine("Distance", receipt.fare.distanceFareCDF, nil)
            fareLine("Time", receipt.fare.timeFareCDF, nil)
            if receipt.fare.waitingFareCDF > 0 {
                fareLine("Waiting", receipt.fare.waitingFareCDF, nil)
            }
            fareLine("Booking fee", receipt.fare.bookingFeeCDF, nil)
            if receipt.fare.surgeFareCDF > 0 {
                let surgeTitle = receipt.fare.surgeMultiplier > 1.001
                    ? String(format: "Peak · %.1f×", receipt.fare.surgeMultiplier)
                    : "Peak"
                fareLine(surgeTitle, receipt.fare.surgeFareCDF, nil)
            }
            if receipt.fare.tollCDF > 0 {
                fareLine("Toll", receipt.fare.tollCDF, nil)
            }
            if receipt.fare.serviceFeeCDF > 0 {
                fareLine("Service fee", receipt.fare.serviceFeeCDF, nil)
            }
            if receipt.fare.taxCDF > 0 {
                fareLine(market == .kenya ? "Tax" : "TVA 16%", receipt.fare.taxCDF, nil)
            }
            if receipt.fare.discountCDF > 0 {
                fareLine("Promo", -receipt.fare.discountCDF, nil)
            }
            if receipt.tipCDF > 0 {
                fareLine("Tip", receipt.tipCDF, nil)
            }

            Text(TripEmissions.displayLabel(distanceKm: receipt.fare.distanceKm, vehicleClass: .standard))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Divider().padding(.vertical, 14)

            HStack(alignment: .firstTextBaseline) {
                Text(receipt.status == .cancelled ? "Total" : "Total charged")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(
                    receipt.status == .cancelled
                        ? AppLocale.formatFareTotal(cdf: 0, usd: 0, market: market)
                        : AppLocale.formatFareTotal(
                            cdf: receipt.chargedTotalCDF,
                            usd: receipt.chargedTotalUSD,
                            market: market
                        )
                )
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.trailing)
            }

            Text("Receipt ID · \(String(receipt.id.prefix(8)).uppercased())")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.top, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VuumColor.pageBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(VuumColor.divider.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func routeBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
        }
    }

    private func metaRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VuumColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }

    private func fareLine(_ title: String, _ cdf: Int, _ usdHint: Double?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(lineAmount(cdf: cdf, usdHint: usdHint))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(cdf < 0 ? Color.green : VuumColor.primaryText)
        }
        .padding(.vertical, 2)
    }

    private func lineAmount(cdf: Int, usdHint: Double?) -> String {
        let absLocal = abs(cdf)
        let sign = cdf < 0 ? "−" : ""
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
        _ = usdHint
        return sign + Money.local(absLocal, market: fareMarket).formatted
    }
}

// MARK: - Help on trip

private struct TripHelpSheet: View {
    let receipt: TripReceipt
    @Environment(\.dismiss) private var dismiss
    @State private var submittedTopic: String?

    private let topics: [(title: String, icon: String)] = [
        ("Lost item", "bag"),
        ("Fare review", "creditcard"),
        ("Safety report", "shield.lefthalf.filled"),
        ("Problem with the driver", "person.crop.circle.badge.exclamationmark"),
        ("Wrong pickup or dropoff", "mappin.and.ellipse"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(receipt.dropoffName)
                            .font(.system(size: 16, weight: .semibold))
                        Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Trip")
                }

                if let submittedTopic {
                    Section {
                        Label("Request received for “\(submittedTopic)”", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Support will follow up using your account phone number.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("How can we help?") {
                        ForEach(topics, id: \.title) { topic in
                            Button {
                                submittedTopic = topic.title
                            } label: {
                                Label(topic.title, systemImage: topic.icon)
                                    .foregroundStyle(VuumColor.primaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trip help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Compatibility wrappers (Account / Payments shortcuts)

struct TripReceiptDetailView: View {
    @EnvironmentObject private var tripSession: TripSession
    let receipt: TripReceipt
    var market: AppLocale.Market = .drc
    @State private var helpReceipt: TripReceipt?
    @State private var shareText: String?

    var body: some View {
        ActivityReceiptDetailView(
            receipt: receipt,
            market: market,
            onRebook: {
                tripSession.rebookFromReceipt(receipt)
                MainTabNavigation.openHome()
            },
            onHelp: { helpReceipt = receipt },
            onShare: {
                shareText = """
                Vuum trip receipt
                \(receipt.date.formatted(date: .complete, time: .shortened))
                From: \(receipt.pickupName)
                To: \(receipt.dropoffName)
                Total: \(AppLocale.formatFareTotal(cdf: receipt.chargedTotalCDF, usd: receipt.chargedTotalUSD, market: market))
                """
            }
        )
        .sheet(item: $helpReceipt) { item in
            TripHelpSheet(receipt: item)
        }
        .sheet(isPresented: Binding(
            get: { shareText != nil },
            set: { if !$0 { shareText = nil } }
        )) {
            if let shareText {
                VuumActivityView(activityItems: [shareText])
            }
        }
    }
}

typealias ActivityView = ActivityHubView
