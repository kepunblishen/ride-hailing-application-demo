import SwiftUI

/// Matching / searching phase — map-dominant with a compact status sheet.
struct SearchingScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @State private var showCancel = false

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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TripMapLayer()

                    .zIndex(0)


                floatingChrome

                VuumSheetChrome(title: nil) {
                    VStack(spacing: 14) {
                        if isNoDrivers {
                            Image(systemName: "car.slash.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(VuumColor.secondaryText)
                                .accessibilityHidden(true)
                        } else {
                            SearchingPulseView()
                                .frame(height: 72)
                        }

                        Text(tripSession.searchMessage)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(VuumColor.primaryText)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .animation(.easeInOut(duration: 0.25), value: tripSession.searchMessage)

                        if isDelayed {
                            Label("Weak connection — still searching", systemImage: "wifi.exclamationmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.brand)
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
                        .foregroundStyle(VuumColor.danger)
                        .accessibilityHint("Opens cancellation reasons")
                    }
                }
                .padding(.horizontal, VuumLayout.pageInset - 4)
                .padding(.bottom, 8)
                .frame(maxHeight: min(VuumLayout.mapSheetMinFraction * geo.size.height, 320), alignment: .bottom)
            }
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

    private var floatingChrome: some View {
        VStack(spacing: 0) {
            HStack {
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
                .accessibilityHint("Opens cancel request")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.top, 8)
            Spacer(minLength: 0)
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
}
