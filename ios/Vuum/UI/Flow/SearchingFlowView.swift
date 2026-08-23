import SwiftUI

/// Matching / searching phase — map-dominant with a compact status sheet.
struct SearchingScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @State private var showCancel = false

    private var tierName: String {
        tripSession.selectedTier?.name ?? "ride"
    }

    private var nearbyCount: Int {
        tripSession.nearbyVehicles.count
    }

    private var isNoDrivers: Bool {
        tripSession.matchingStatus == .noDrivers
    }

    private var isDelayed: Bool {
        tripSession.matchingStatus == .delayed
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TripMapLayer()

            VuumSheetChrome(title: nil) {
                VStack(spacing: 16) {
                    if isNoDrivers {
                        Image(systemName: "car.slash.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                            .accessibilityHidden(true)
                    } else {
                        SearchingPulseView()
                    }

                    Text(tripSession.searchMessage)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.25), value: tripSession.searchMessage)

                    if isDelayed {
                        Label("Weak connection — still searching", systemImage: "wifi.exclamationmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.orange)
                    } else if isNoDrivers {
                        Text("No partners accepted nearby. Try again or change ride category.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                            .multilineTextAlignment(.center)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12, weight: .semibold))
                                Text(matchCountdownLabel)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(VuumColor.secondaryText)
                        }
                    }

                    if let tier = tripSession.selectedTier {
                        HStack(spacing: 10) {
                            metaChip(icon: tier.systemImage, title: tier.name)
                            RideClassETABadge(minutes: tier.classETABadgeMinutes, compact: true)
                            metaChip(
                                icon: "car.2.fill",
                                title: nearbyCount == 1 ? "1 nearby" : "\(nearbyCount) nearby"
                            )
                        }
                    } else {
                        HStack(spacing: 10) {
                            metaChip(icon: "car.fill", title: tierName)
                            metaChip(
                                icon: "car.2.fill",
                                title: nearbyCount == 1 ? "1 nearby" : "\(nearbyCount) nearby"
                            )
                        }
                    }

                    if let dropoff = tripSession.dropoff {
                        VStack(alignment: .leading, spacing: 6) {
                            routeLine(icon: "circle.fill", color: VuumColor.brand, title: tripSession.pickup.name)
                            routeLine(icon: "mappin.circle.fill", color: VuumColor.primaryText, title: dropoff.name)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    if isNoDrivers {
                        VuumPrimaryButton(title: "Try again") {
                            tripSession.retrySearch()
                        }
                    }

                    Button("Cancel request") {
                        showCancel = true
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .padding(.top, 2)
                    .accessibilityHint("Opens cancellation reasons")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showCancel) {
            CancelTripSheet(
                title: "Cancel request?",
                isFree: true,
                feeLocal: 0,
                market: AppLocale.current
            ) { reason in
                tripSession.cancelSearch(reason: reason)
            }
        }
    }

    private var matchCountdownLabel: String {
        let seconds = tripSession.estimatedMatchingSeconds
        if tripSession.matchingStatus == .retrying {
            return seconds <= 0 ? "Connecting you now" : "Retrying · \(seconds)s"
        }
        if seconds <= 0 {
            return "Connecting you now"
        }
        return "Usually under \(seconds)s"
    }

    private func metaChip(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VuumColor.chipBackground, in: Capsule())
    }

    private func routeLine(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(1)
        }
    }
}
