import SwiftUI

/// Post-trip: itemized receipt, tip, 1–5 rating, tags, comment, skip, rebook.
struct PostTripCompleteView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @State private var showIncidentReport = false
    @FocusState private var commentFocused: Bool

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var receipt: TripReceipt? {
        tripSession.lastReceipt ?? tripSession.activeTrip.map { trip in
            TripReceipt(
                id: "live",
                date: Date(),
                pickupName: trip.pickup.name,
                dropoffName: trip.dropoff.name,
                stopNames: trip.stops.map(\.name),
                driverName: trip.driver.name,
                vehicle: trip.driver.vehicle,
                plate: trip.driver.plate,
                tierName: trip.tier.name,
                paymentMethod: trip.paymentMethod,
                fare: trip.fare,
                tipCDF: tripSession.draftTipCDF
            )
        }
    }

    private var tipPresets: [Int] { PostTripFeedback.tipPresets(market: market) }

    private var feedbackTags: [String] {
        PostTripFeedback.tags(for: tripSession.draftRating)
    }

    private var appreciationLine: String? {
        guard tripSession.draftRating >= 4 else { return nil }
        let name = receipt?.driverName.components(separatedBy: " ").first ?? "your driver"
        return "Thanks — \(name) will see your appreciation."
    }

    var body: some View {
        ZStack {
            VuumColor.pageBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VuumLayout.stackSpacing + 8) {
                    header
                    if tripSession.incidentFlagged, tripSession.audioRecorder.hasRecordingFile {
                        audioRetainedBanner
                    }
                    if let receipt {
                        PostTripReceiptCard(receipt: receipt, tipCDF: tripSession.draftTipCDF, market: market)
                    }
                    tipSection
                    ratingSection
                    if let appreciationLine {
                        Text(appreciationLine)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VuumColor.brandInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(VuumLayout.rowSpacing)
                            .background(VuumColor.brand.opacity(0.14), in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous))
                    }
                    tagsSection
                    commentSection
                    incidentButton
                    actions
                }
                .padding(VuumLayout.pageInset + 8)
                .padding(.bottom, VuumLayout.sectionSpacing)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showIncidentReport) {
            IncidentReportView()
                .environmentObject(tripSession)
        }
        .onChange(of: tripSession.draftRating) { _, _ in
            let allowed = Set(feedbackTags)
            tripSession.draftRatingTags = Set(tripSession.draftRatingTags.filter { allowed.contains($0) })
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(VuumColor.brand)
                .symbolEffect(.bounce, value: tripSession.draftRating)
                .accessibilityHidden(true)
            Text("You've arrived")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(VuumColor.primaryText)
            if let driver = receipt?.driverName {
                Text("How was your trip with \(driver)?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VuumLayout.rowSpacing)
    }

    private var audioRetainedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "waveform.badge.mic")
                .foregroundStyle(VuumColor.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trip audio retained")
                    .font(.system(size: 14, weight: .bold))
                Text("Kept on this device for Safety review with your incident report.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VuumColor.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a tip")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
            Text("100% goes to your driver")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
            HStack(spacing: 8) {
                ForEach(tipPresets, id: \.self) { amount in
                    let selected = tripSession.draftTipCDF == amount
                    Button {
                        tripSession.setDraftTip(amount)
                    } label: {
                        Text(amount == 0 ? "No tip" : AppLocale.formatPrimary(local: amount, market: market))
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .foregroundStyle(selected ? VuumColor.accentOn : VuumColor.primaryText)
                            .background(
                                selected ? VuumColor.emphasizedFill : VuumColor.chipBackground,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(amount == 0 ? "No tip" : "Tip \(AppLocale.formatPrimary(local: amount, market: market))")
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rate your trip")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            tripSession.draftRating = star
                        }
                    } label: {
                        Image(systemName: star <= tripSession.draftRating ? "star.fill" : "star")
                            .font(.system(size: 30))
                            .foregroundStyle(VuumColor.brand)
                            .scaleEffect(star <= tripSession.draftRating ? 1.08 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star <= tripSession.draftRating ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What stood out?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
            PostTripTagWrap(tags: feedbackTags, selected: tripSession.draftRatingTags) { tag in
                tripSession.toggleDraftRatingTag(tag)
            }
        }
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a comment")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
            TextField("Optional — share more about the ride", text: $tripSession.draftRatingComment, axis: .vertical)
                .lineLimit(3...5)
                .foregroundStyle(VuumColor.primaryText)
                .padding(12)
                .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous))
                .focused($commentFocused)
        }
    }

    private var incidentButton: some View {
        Button {
            showIncidentReport = true
        } label: {
            Label("Report an incident", systemImage: "exclamationmark.shield")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(VuumColor.primaryText)
                .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            VuumPrimaryButton(title: "Submit rating") {
                tripSession.submitRatingAndFinish()
            }
            if let receipt = tripSession.lastReceipt {
                Button {
                    tripSession.rebookFromReceipt(receipt)
                } label: {
                    Label("Rebook this trip", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(VuumColor.primaryText)
                        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Button {
                tripSession.skipRatingAndFinish()
            } label: {
                Text("Skip for now")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Receipt card

struct PostTripReceiptCard: View {
    let receipt: TripReceipt
    var tipCDF: Int = 0
    let market: AppLocale.Market

    private var effectiveTip: Int { max(tipCDF, receipt.tipCDF) }

    private var chargedCDF: Int { receipt.fare.totalCDF + max(effectiveTip, 0) }

    private var chargedUSD: Double {
        let tip = max(effectiveTip, 0)
        guard tip > 0, receipt.fare.totalCDF > 0 else { return receipt.fare.totalUSD }
        return receipt.fare.totalUSD * (Double(receipt.fare.totalCDF + tip) / Double(receipt.fare.totalCDF))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("VUUM")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                Text("Receipt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(VuumColor.chipBackground, in: Capsule())
            }
            .padding(.bottom, 14)

            Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 13))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.bottom, 12)

            Text("\(receipt.pickupName) → \(receipt.dropoffName)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
                .padding(.bottom, 8)

            metaRow("Driver", receipt.driverName)
            if !receipt.vehicleLabel.isEmpty {
                metaRow("Vehicle", receipt.vehicleLabel)
            }
            metaRow("Product", receipt.tierName)
            metaRow("Payment", receipt.paymentMethod.title)
            metaRow("Distance", String(format: "%.1f km", receipt.fare.distanceKm))
            metaRow("Duration", TripGeo.formatDuration(minutes: receipt.fare.durationMinutes))

            Divider().padding(.vertical, 12)

            Text("Fare breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.bottom, 6)

            fareLine("Base fare", receipt.fare.baseFareCDF)
            fareLine("Distance", receipt.fare.distanceFareCDF)
            fareLine("Time", receipt.fare.timeFareCDF)
            fareLine("Booking fee", receipt.fare.bookingFeeCDF)
            if receipt.fare.waitingFareCDF > 0 {
                fareLine("Waiting", receipt.fare.waitingFareCDF)
            }
            if receipt.fare.surgeFareCDF > 0 {
                let label = receipt.fare.surgeMultiplier > 1.001
                    ? String(format: "Peak ×%.1f", receipt.fare.surgeMultiplier)
                    : "Peak"
                fareLine(label, receipt.fare.surgeFareCDF)
            }
            if receipt.fare.tollCDF > 0 {
                fareLine("Tolls", receipt.fare.tollCDF)
            }
            if receipt.fare.serviceFeeCDF > 0 {
                fareLine("Service fee", receipt.fare.serviceFeeCDF)
            }
            if receipt.fare.discountCDF > 0 {
                fareLine("Promo", -receipt.fare.discountCDF)
            }
            if receipt.fare.taxCDF > 0 {
                fareLine(market == .kenya ? "Tax" : "TVA 16%", receipt.fare.taxCDF)
            }
            if receipt.fare.subtotalCDF > 0, receipt.fare.subtotalCDF != receipt.fare.totalCDF {
                fareLine("Subtotal", receipt.fare.subtotalCDF)
            }
            if effectiveTip > 0 {
                fareLine("Tip", effectiveTip)
            }

            Text(TripEmissions.displayLabel(
                distanceKm: receipt.fare.distanceKm,
                vehicleClass: VehicleClass.resolving(tierID: receipt.tierName)
            ))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.top, 6)

            Divider().padding(.vertical, 12)

            HStack(alignment: .firstTextBaseline) {
                Text("Total")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(AppLocale.formatPrimary(local: chargedCDF, market: market))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(VuumColor.primaryText)
                    if market != .kenya {
                        Text(AppLocale.formatUSDLabeled(chargedUSD))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }
            }

            Text("Receipt ID · \(String(receipt.id.prefix(8)).uppercased())")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.top, 12)
        }
        .padding(16)
        .VuumGlassCard(cornerRadius: 18)
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
        .padding(.vertical, 2)
    }

    private func fareLine(_ title: String, _ cdf: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(lineAmount(cdf))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(cdf < 0 ? VuumColor.success : VuumColor.primaryText)
        }
        .padding(.vertical, 2)
    }

    private func lineAmount(_ cdf: Int) -> String {
        let absCDF = abs(cdf)
        let sign = cdf < 0 ? "−" : ""
        return "\(sign)\(AppLocale.formatPrimary(local: absCDF, market: market))"
    }
}

// MARK: - Tag wrap

private struct PostTripTagWrap: View {
    let tags: [String]
    let selected: Set<String>
    let onToggle: (String) -> Void

    var body: some View {
        PostTripFlexibleLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isOn = selected.contains(tag)
                Button {
                    onToggle(tag)
                } label: {
                    Text(tag)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(isOn ? VuumColor.accentOn : VuumColor.primaryText)
                        .background(isOn ? VuumColor.emphasizedFill : VuumColor.chipBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

private struct PostTripFlexibleLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), frames)
    }
}
