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
            .background(VuumColor.groupedBackground.ignoresSafeArea())
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
        VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
            Picker("Activity", selection: $segment) {
                ForEach(ActivitySegment.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VuumLayout.chipSpacing) {
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
                                    .font(VuumType.captionSemibold)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(productFilter == "All" ? VuumColor.primaryText : VuumColor.accentOn)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                productFilter == "All" ? VuumColor.chipBackground : VuumColor.brand,
                                in: Capsule()
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, VuumLayout.pageInset)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(VuumColor.pageBackground)
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VuumType.captionSemibold)
                .foregroundStyle(selected ? VuumColor.accentOn : VuumColor.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selected ? VuumColor.brand : VuumColor.chipBackground,
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
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground)
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
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground)
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
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground)
        }
    }

    private func emptyState(title: String, systemImage: String, message: String) -> some View {
        let showBook = tripSession.tripHistory.isEmpty
            && (segment == .all || segment == .completed || segment == .cancelled)
        let showServices = tripSession.reservedTrips.isEmpty && segment == .upcoming
        return ActivityEmptyStateView(
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
        HStack(alignment: .top, spacing: VuumLayout.rowSpacing) {
            Image(systemName: receipt.status == .cancelled ? "xmark.circle.fill" : "car.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(receipt.status == .cancelled ? VuumColor.secondaryText : VuumColor.brand)
                .frame(width: VuumLayout.iconBadgeLarge, height: VuumLayout.iconBadgeLarge)
                .background(
                    (receipt.status == .cancelled
                        ? VuumColor.secondaryText.opacity(0.14)
                        : VuumColor.brand.opacity(0.18)),
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusChip, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(receipt.dropoffName)
                        .font(VuumType.rowTitle)
                        .foregroundStyle(VuumColor.primaryText)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(receipt.status.title)
                        .font(VuumType.micro)
                        .foregroundStyle(receipt.status == .cancelled ? VuumColor.secondaryText : VuumColor.brand)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            (receipt.status == .cancelled
                                ? VuumColor.secondaryText.opacity(0.12)
                                : VuumColor.brand.opacity(0.16)),
                            in: Capsule()
                        )
                }
                Text("\(receipt.pickupName) · \(receipt.tierName)")
                    .font(VuumType.caption)
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
                HStack(alignment: .firstTextBaseline) {
                    Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                    Spacer(minLength: 8)
                    if receipt.status == .cancelled {
                        Text("No charge")
                            .font(VuumType.callout)
                            .foregroundStyle(VuumColor.secondaryText)
                    } else {
                        Text(
                            AppLocale.formatFareTotal(
                                cdf: receipt.chargedTotalCDF,
                                usd: receipt.chargedTotalUSD,
                                market: market
                            )
                        )
                        .font(VuumType.callout)
                        .foregroundStyle(VuumColor.primaryText)
                    }
                }
                HStack(spacing: VuumLayout.chipSpacing) {
                    Label(receipt.paymentMethod.title, systemImage: receipt.paymentMethod.systemImage)
                    if let rating = receipt.rating {
                        Label("\(rating)", systemImage: "star.fill")
                    }
                }
                .font(VuumType.micro)
                .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .padding(.vertical, 6)
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
            HStack(alignment: .top, spacing: VuumLayout.rowSpacing) {
                Image(systemName: trip.status == .driverAssigned ? "car.fill" : "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: VuumLayout.iconBadgeLarge, height: VuumLayout.iconBadgeLarge)
                    .background(
                        VuumColor.brand.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: VuumLayout.radiusChip, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(trip.pickupName) → \(trip.dropoffName)")
                        .font(VuumType.rowTitle)
                        .foregroundStyle(VuumColor.primaryText)
                        .lineLimit(2)
                    Text(trip.when.formatted(date: .complete, time: .shortened))
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                    Text("\(trip.tierName) · \(AppLocale.formatFareTotal(cdf: trip.priceCDF, usd: trip.priceUSD, market: market))")
                        .font(VuumType.callout)
                        .foregroundStyle(VuumColor.primaryText)
                    Text(trip.statusDetailLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.brand)
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
                    .font(VuumType.bodySemibold)
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
                            .foregroundStyle(VuumColor.primaryText)
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
                .font(VuumType.bodySemibold)
                .foregroundStyle(VuumColor.brand)
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
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
    @Environment(\.colorScheme) private var colorScheme
    let receipt: TripReceipt
    let market: AppLocale.Market
    let onRebook: () -> Void
    let onHelp: () -> Void
    let onShare: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                receiptCard

                VStack(spacing: VuumLayout.stackSpacing) {
                    if receipt.status == .completed {
                        VuumPrimaryButton(title: "Rebook this trip", action: onRebook)
                    }
                    Button(action: onHelp) {
                        Label("Get help with this trip", systemImage: "questionmark.circle")
                            .font(VuumType.bodySemibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(VuumColor.primaryText)
                            .background(
                                VuumColor.chipBackground,
                                in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    Button(action: onShare) {
                        Label("Share receipt", systemImage: "square.and.arrow.up")
                            .font(VuumType.callout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(VuumColor.brand)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, VuumLayout.pageInset)
            }
            .padding(.vertical, VuumLayout.pageInset)
        }
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("VUUM")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(VuumColor.brand)
                Spacer()
                Text(receipt.status.title)
                    .font(VuumType.micro)
                    .foregroundStyle(VuumColor.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(VuumColor.chipBackground, in: Capsule())
            }
            .padding(.bottom, 16)

            Text(receipt.date.formatted(date: .complete, time: .shortened))
                .font(VuumType.caption)
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.bottom, 18)

            routeBlock(title: "From", value: receipt.pickupName)
            if !receipt.stopNames.isEmpty {
                Divider().padding(.vertical, VuumLayout.rowSpacing)
                routeBlock(title: "Stops", value: receipt.stopNames.joined(separator: " → "))
            }
            Divider().padding(.vertical, VuumLayout.rowSpacing)
            routeBlock(title: "To", value: receipt.dropoffName)
            Divider().padding(.vertical, VuumLayout.rowSpacing)

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
                .font(VuumType.captionSemibold)
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
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.top, 6)

            Divider().padding(.vertical, 14)

            HStack(alignment: .firstTextBaseline) {
                Text(receipt.status == .cancelled ? "Total" : "Total charged")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
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
                .foregroundStyle(VuumColor.primaryText)
                .multilineTextAlignment(.trailing)
            }

            Text("Receipt ID · \(String(receipt.id.prefix(8)).uppercased())")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.top, 16)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                .fill(VuumColor.cardBackground)
                .shadow(color: VuumColor.glassShadow(for: colorScheme), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
                .strokeBorder(VuumColor.divider.opacity(0.7), lineWidth: 1)
        )
        .padding(.horizontal, VuumLayout.pageInset)
    }

    private func routeBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(VuumType.micro)
                .foregroundStyle(VuumColor.secondaryText)
            Text(value)
                .font(VuumType.rowTitle)
                .foregroundStyle(VuumColor.primaryText)
        }
    }

    private func metaRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer(minLength: 12)
            Text(value)
                .font(VuumType.callout)
                .foregroundStyle(VuumColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }

    private func fareLine(_ title: String, _ cdf: Int, _ usdHint: Double?) -> some View {
        HStack {
            Text(title)
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(lineAmount(cdf: cdf, usdHint: usdHint))
                .font(VuumType.callout)
                .foregroundStyle(cdf < 0 ? VuumColor.success : VuumColor.primaryText)
        }
        .padding(.vertical, 3)
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
                            .font(VuumType.rowTitle)
                            .foregroundStyle(VuumColor.primaryText)
                        Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                            .font(VuumType.caption)
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Trip")
                }

                if let submittedTopic {
                    Section {
                        Label("Request received for “\(submittedTopic)”", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(VuumColor.success)
                        Text("Support will follow up using your account phone number.")
                            .font(.footnote)
                            .foregroundStyle(VuumColor.secondaryText)
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
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

// MARK: - Activity empty state (semantic colors; Activity-scoped)

private struct ActivityEmptyStateView: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 64, height: 64)
                .background(
                    VuumColor.brand.opacity(colorScheme == .dark ? 0.28 : 0.14),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(VuumType.button)
                        .foregroundStyle(VuumColor.accentOn)
                        .frame(maxWidth: 260)
                        .frame(height: 46)
                        .background(
                            VuumColor.brand,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VuumColor.groupedBackground)
        .accessibilityElement(children: .contain)
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
