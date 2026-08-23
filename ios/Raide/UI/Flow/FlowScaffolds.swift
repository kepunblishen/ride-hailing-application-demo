import SwiftUI

/// Home shell — map + “Where to?” entry. Full UI polish comes next.
struct HomeMapScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack(alignment: .bottom) {
            RaideMapView(cameraTarget: tripSession.pickup.coordinate)
                .ignoresSafeArea()

            RaideSheetChrome(title: nil) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(RaideTheme.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(RaideColor.brand)

                    Button {
                        tripSession.beginDestinationSelection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(RaideColor.secondaryText)
                            Text("Where to?")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(RaideColor.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(RaideColor.pageBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            RaideMapView(cameraTarget: tripSession.pickup.coordinate)
                .ignoresSafeArea()

            RaideSheetChrome(title: "Choose destination") {
                VStack(spacing: 0) {
                    ForEach(MockPlaces.destinations) { place in
                        Button {
                            tripSession.selectDestination(place)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(RaideColor.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(RaideColor.primaryText)
                                    Text(place.subtitle)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(RaideColor.secondaryText)
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
                    .foregroundStyle(RaideColor.secondaryText)
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
            RaideMapView(cameraTarget: tripSession.dropoff?.coordinate ?? tripSession.pickup.coordinate)
                .ignoresSafeArea()

            RaideSheetChrome(title: "Choose a ride") {
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
                                        .foregroundStyle(RaideColor.secondaryText)
                                }
                                Spacer()
                                Text(tier.priceEstimate)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(RaideColor.primaryText)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        tripSession.selectedTier?.id == tier.id ? RaideColor.brand : RaideColor.divider,
                                        lineWidth: tripSession.selectedTier?.id == tier.id ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    RaidePrimaryButton(title: "Confirm Raide") {
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
            RaideColor.brandInk.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(RaideColor.brand)
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
            RaideMapView(cameraTarget: tripSession.activeTrip?.driverCoordinate ?? tripSession.pickup.coordinate)
                .ignoresSafeArea()

            RaideSheetChrome(title: tripSession.phase == .assigned ? "Driver on the way" : "Trip in progress") {
                if let trip = tripSession.activeTrip {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(trip.driver.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("\(trip.driver.vehicle) · \(trip.driver.plate)")
                            .foregroundStyle(RaideColor.secondaryText)
                        Text("ETA \(trip.driver.etaMinutes) min · \(trip.fare)")
                            .font(.system(size: 15, weight: .medium, design: .rounded))

                        if tripSession.phase == .assigned {
                            RaidePrimaryButton(title: "Start trip (demo)") {
                                tripSession.startTrip()
                            }
                        } else {
                            RaidePrimaryButton(title: "Complete trip (demo)") {
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
            RaideColor.pageBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(RaideColor.brand)
                Text("Trip complete")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                if let fare = tripSession.activeTrip?.fare {
                    Text(fare)
                        .foregroundStyle(RaideColor.secondaryText)
                }
                RaidePrimaryButton(title: "Back to home") {
                    tripSession.resetToHome()
                }
                .padding(.horizontal, 24)
            }
            .padding(24)
        }
    }
}
