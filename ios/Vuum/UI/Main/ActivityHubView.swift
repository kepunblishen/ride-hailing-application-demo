import SwiftUI

// MARK: - Time filter (toolbar menu only)

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

    @State private var timeFilter: ActivityTimeFilter = .all
    @State private var helpReceipt: TripReceipt?
    @State private var shareText: String?

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var filteredHistory: [TripReceipt] {
        tripSession.tripHistory.filter { timeFilter.includes($0.date) }
    }

    private var filteredReservations: [ReservedTrip] {
        tripSession.reservedTrips
            .filter { timeFilter.includes($0.when) }
            .sorted { $0.when < $1.when }
    }

    var body: some View {
        NavigationStack {
            VuumHubLoadContainer {
                content
            }
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .navigationTitle(L10n.t("activity.title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ActivityTimeFilter.allCases) { filter in
                            Button {
                                timeFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.title)
                                    if timeFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(
                                timeFilter == .all ? VuumColor.secondaryText : VuumColor.brand
                            )
                            .accessibilityLabel("Time range")
                    }
                }
            }
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
            }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if filteredHistory.isEmpty, filteredReservations.isEmpty {
            emptyState
        } else {
            List {
                if !filteredReservations.isEmpty {
                    Section {
                        ForEach(filteredReservations) { trip in
                            NavigationLink {
                                ReservedTripDetailView(trip: trip, market: market)
                            } label: {
                                UpcomingTripRow(trip: trip, market: market)
                            }
                        }
                    } header: {
                        Text("Upcoming")
                    }
                }

                if !filteredHistory.isEmpty {
                    Section {
                        ForEach(filteredHistory) { receipt in
                            NavigationLink(value: receipt) {
                                PastTripRow(receipt: receipt, market: market)
                            }
                        }
                    } header: {
                        if !filteredReservations.isEmpty {
                            Text("Past")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground)
        }
    }

    private var emptyState: some View {
        let hasAnyTrips = !tripSession.tripHistory.isEmpty || !tripSession.reservedTrips.isEmpty
        return ActivityEmptyStateView(
            systemImage: "clock",
            title: hasAnyTrips ? "No trips in this range" : L10n.t("activity.empty_title"),
            message: hasAnyTrips
                ? "Try a different time range from the calendar menu."
                : L10n.t("activity.empty_detail"),
            actionTitle: hasAnyTrips ? nil : L10n.t("status.empty_trips_action"),
            action: hasAnyTrips ? nil : { MainTabNavigation.openHome(beginBooking: true) }
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

    private var fareLabel: String {
        if receipt.status == .cancelled {
            return "No charge"
        }
        return AppLocale.formatFareTotal(
            cdf: receipt.chargedTotalCDF,
            usd: receipt.chargedTotalUSD,
            market: market
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(receipt.dropoffName)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(fareLabel)
                    .font(VuumType.callout)
                    .foregroundStyle(
                        receipt.status == .cancelled
                            ? VuumColor.secondaryText
                            : VuumColor.primaryText
                    )
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
                if receipt.status == .cancelled {
                    Text("·")
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.tertiaryText)
                    Text(receipt.status.title)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(receipt.dropoffName), \(receipt.status.title), \(receipt.date.formatted(date: .abbreviated, time: .shortened)), \(fareLabel)"
        )
    }
}

private struct UpcomingTripRow: View {
    let trip: ReservedTrip
    let market: AppLocale.Market
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(trip.dropoffName)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(
                    AppLocale.formatFareTotal(
                        cdf: trip.priceCDF,
                        usd: trip.priceUSD,
                        market: market
                    )
                )
                .font(VuumType.callout)
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(trip.when.formatted(date: .abbreviated, time: .shortened))
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
                Text("·")
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.tertiaryText)
                Text(trip.status.title)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }

            if let onCancel {
                Button("Cancel reservation", role: .destructive, action: onCancel)
                    .font(VuumType.bodySemibold)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Receipt detail

struct ActivityReceiptDetailView: View {
    let receipt: TripReceipt
    let market: AppLocale.Market
    let onRebook: () -> Void
    let onHelp: () -> Void
    let onShare: () -> Void

    private var totalLabel: String {
        if receipt.status == .cancelled {
            return AppLocale.formatFareTotal(cdf: 0, usd: 0, market: market)
        }
        return AppLocale.formatFareTotal(
            cdf: receipt.chargedTotalCDF,
            usd: receipt.chargedTotalUSD,
            market: market
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(receipt.dropoffName)
                        .font(VuumType.titleSmall)
                        .foregroundStyle(VuumColor.primaryText)
                    Text(receipt.date.formatted(date: .complete, time: .shortened))
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                    Text(receipt.status.title)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            }

            Section("Route") {
                LabeledContent("From", value: receipt.pickupName)
                if !receipt.stopNames.isEmpty {
                    LabeledContent("Stops", value: receipt.stopNames.joined(separator: " → "))
                }
                LabeledContent("To", value: receipt.dropoffName)
                LabeledContent("Distance", value: String(format: "%.1f km", receipt.fare.distanceKm))
                LabeledContent(
                    "Duration",
                    value: TripGeo.formatDuration(minutes: receipt.fare.durationMinutes)
                )
            }

            Section("Fare") {
                fareRow("Base fare", receipt.fare.baseFareCDF)
                fareRow("Distance", receipt.fare.distanceFareCDF)
                fareRow("Time", receipt.fare.timeFareCDF)
                if receipt.fare.waitingFareCDF > 0 {
                    fareRow("Waiting", receipt.fare.waitingFareCDF)
                }
                fareRow("Booking fee", receipt.fare.bookingFeeCDF)
                if receipt.fare.surgeFareCDF > 0 {
                    let surgeTitle = receipt.fare.surgeMultiplier > 1.001
                        ? String(format: "Peak · %.1f×", receipt.fare.surgeMultiplier)
                        : "Peak"
                    fareRow(surgeTitle, receipt.fare.surgeFareCDF)
                }
                if receipt.fare.tollCDF > 0 {
                    fareRow("Toll", receipt.fare.tollCDF)
                }
                if receipt.fare.serviceFeeCDF > 0 {
                    fareRow("Service fee", receipt.fare.serviceFeeCDF)
                }
                if receipt.fare.taxCDF > 0 {
                    fareRow(market == .kenya ? "Tax" : "TVA 16%", receipt.fare.taxCDF)
                }
                if receipt.fare.discountCDF > 0 {
                    fareRow("Promo", -receipt.fare.discountCDF)
                }
                if receipt.tipCDF > 0 {
                    fareRow("Tip", receipt.tipCDF)
                }
                HStack {
                    Text(receipt.status == .cancelled ? "Total" : "Total charged")
                        .font(VuumType.bodySemibold)
                        .foregroundStyle(VuumColor.primaryText)
                    Spacer()
                    Text(totalLabel)
                        .font(VuumType.bodySemibold)
                        .foregroundStyle(VuumColor.primaryText)
                }
            }

            Section("Trip details") {
                LabeledContent("Driver", value: receipt.driverName)
                if !receipt.vehicleLabel.isEmpty {
                    LabeledContent("Vehicle", value: receipt.vehicleLabel)
                }
                LabeledContent("Product", value: receipt.tierName)
                LabeledContent("Payment", value: receipt.paymentMethod.title)
                if let rating = receipt.rating {
                    LabeledContent("Your rating", value: "\(rating) / 5")
                }
                if !receipt.feedbackTags.isEmpty {
                    LabeledContent("Feedback", value: receipt.feedbackTags.joined(separator: " · "))
                }
                if let note = receipt.feedbackNote, !note.isEmpty {
                    LabeledContent("Comment", value: note)
                }
                if let reason = receipt.cancelReason, !reason.isEmpty {
                    LabeledContent("Cancel reason", value: reason)
                }
                LabeledContent(
                    "Receipt ID",
                    value: String(receipt.id.prefix(8)).uppercased()
                )
            }

            Section {
                if receipt.status == .completed {
                    Button(action: onRebook) {
                        Text("Rebook this trip")
                            .font(VuumType.bodySemibold)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(VuumColor.brand)
                    }
                }
                Button(action: onHelp) {
                    Label("Get help with this trip", systemImage: "questionmark.circle")
                        .font(VuumType.bodySemibold)
                        .foregroundStyle(VuumColor.primaryText)
                }
                Button(action: onShare) {
                    Label("Share receipt", systemImage: "square.and.arrow.up")
                        .font(VuumType.callout)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fareRow(_ title: String, _ cdf: Int) -> some View {
        HStack {
            Text(title)
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(lineAmount(cdf: cdf))
                .font(VuumType.callout)
                .foregroundStyle(cdf < 0 ? VuumColor.success : VuumColor.primaryText)
        }
    }

    private func lineAmount(cdf: Int) -> String {
        let absLocal = abs(cdf)
        let sign = cdf < 0 ? "−" : ""
        let fareMarket: AppLocale.Market = market == .kenya ? .kenya : .drc
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

// MARK: - Activity empty state

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
                .foregroundStyle(VuumColor.secondaryText)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 64, height: 64)
                .background(
                    VuumColor.chipBackground,
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
