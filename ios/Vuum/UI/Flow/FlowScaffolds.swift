import SwiftUI

/// Home shell — map + “Where to?” entry. Full UI polish comes next.
struct HomeMapScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack(alignment: .bottom) {
            VuumMapView(cameraTarget: tripSession.pickup.coordinate)
                .ignoresSafeArea()

            VuumSheetChrome(title: nil) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(VuumTheme.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(VuumColor.brand)

                    Button {
                        tripSession.beginDestinationSelection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(VuumColor.secondaryText)
                            Text("Where to?")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(VuumColor.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(VuumColor.pageBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct DestinationScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack(alignment: .bottom) {
            VuumMapView(cameraTarget: tripSession.pickup.coordinate)
                .ignoresSafeArea()

            VuumSheetChrome(title: "Choose destination") {
                VStack(spacing: 0) {
                    ForEach(MockPlaces.destinations) { place in
                        Button {
                            tripSession.selectDestination(place)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(VuumColor.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(VuumColor.primaryText)
                                    Text(place.subtitle)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(VuumColor.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if place.id != MockPlaces.destinations.last?.id {
                            Divider()
                        }
                    }

                    Button("Cancel") {
                        tripSession.resetToHome()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VuumColor.secondaryText)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct RideOptionsScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack(alignment: .bottom) {
            VuumMapView(cameraTarget: tripSession.dropoff?.coordinate ?? tripSession.pickup.coordinate)
                .ignoresSafeArea()

            VuumSheetChrome(title: "Choose a ride") {
                VStack(spacing: 10) {
                    ForEach(tripSession.availableTiers) { tier in
                        Button {
                            tripSession.chooseTier(tier)
                        } label: {
                            HStack {
                                Image(systemName: tier.systemImage)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.name)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("\(tier.etaMinutes) min · \(tier.detail)")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(VuumColor.secondaryText)
                                }
                                Spacer()
                                Text(tier.priceEstimate)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(VuumColor.primaryText)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        tripSession.selectedTier?.id == tier.id ? VuumColor.brand : VuumColor.divider,
                                        lineWidth: tripSession.selectedTier?.id == tier.id ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    VuumPrimaryButton(title: "Confirm Vuum") {
                        tripSession.confirmRequest()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct SearchingScaffoldView: View {
    var body: some View {
        ZStack {
            VuumColor.brandInk.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(VuumColor.brand)
                    .scaleEffect(1.3)
                Text("Finding your driver…")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct ActiveTripScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack(alignment: .bottom) {
            VuumMapView(cameraTarget: tripSession.activeTrip?.driverCoordinate ?? tripSession.pickup.coordinate)
                .ignoresSafeArea()

            VuumSheetChrome(title: tripSession.phase == .assigned ? "Driver on the way" : "Trip in progress") {
                if let trip = tripSession.activeTrip {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(trip.driver.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(trip.driver.vehicle) · \(trip.driver.plate)")
                            .foregroundStyle(VuumColor.secondaryText)
                        Text("ETA \(trip.driver.etaMinutes) min · \(trip.fare)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))

                        if tripSession.phase == .assigned {
                            VuumPrimaryButton(title: "Start trip (demo)") {
                                tripSession.startTrip()
                            }
                        } else {
                            VuumPrimaryButton(title: "Complete trip (demo)") {
                                tripSession.completeTrip()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct TripCompleteScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack {
            VuumColor.pageBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(VuumColor.brand)
                Text("Trip complete")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if let fare = tripSession.activeTrip?.fare {
                    Text(fare)
                        .foregroundStyle(VuumColor.secondaryText)
                }
                VuumPrimaryButton(title: "Back to home") {
                    tripSession.resetToHome()
                }
                .padding(.horizontal, 24)
            }
            .padding(24)
        }
    }
}
