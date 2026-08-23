import SwiftUI

// MARK: - Class ETA (2 / 5 / 10)

extension RideTier {
    /// Pickup ETA badge by vehicle class: bike 2 · car 5 · XXL / executive 10.
    var classETABadgeMinutes: Int {
        VehiclePickupETA.minutes(for: vehicleClass)
    }

    /// Product-resolved glyph for choose-ride rows (ServiceProductID over stored badge icons).
    var productSystemImage: String {
        ServiceProductID.systemImage(forProductID: id)
    }

    /// Wall-clock dropoff after pickup wait + trip time for the given route distance.
    func estimatedDropoffDate(routeDistanceMeters: Double, from date: Date = .init()) -> Date {
        let pickup = max(1, etaMinutes)
        let trip = TripGeo.etaMinutes(
            distanceMeters: max(0, routeDistanceMeters),
            speedKmh: VehiclePickupETA.tripSpeedKmh(for: vehicleClass)
        )
        return date.addingTimeInterval(TimeInterval((pickup + trip) * 60))
    }

    /// Secondary meta: `"5 min · 3:42 PM"`.
    func etaAndDropoffLabel(routeDistanceMeters: Double, from date: Date = .init()) -> String {
        let pickup = max(1, etaMinutes)
        let dropoff = estimatedDropoffDate(routeDistanceMeters: routeDistanceMeters, from: date)
            .formatted(date: .omitted, time: .shortened)
        return "\(pickup) min · \(dropoff)"
    }
}

/// Compact pill used on ride-class rows and the active driver card.
struct RideClassETABadge: View {
    let minutes: Int
    var compact: Bool = false

    var body: some View {
        Text("\(max(minutes, 1)) min")
            .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
            .foregroundStyle(VuumColor.accentOn)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 5)
            .background(VuumColor.brand, in: Capsule(style: .continuous))
            .accessibilityLabel("Estimated arrival \(max(minutes, 1)) minutes")
    }
}

// MARK: - Driver profile helpers

extension DriverProfile {
    /// One or two initials for avatar fallback when no photo asset is set.
    var initials: String {
        let parts = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "." })
            .map(String.init)
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            let a = parts[0].prefix(1)
            let b = parts[1].prefix(1)
            return "\(a)\(b)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var vehicleMakeModel: String {
        let parts = vehicle.split(separator: "·", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return parts.first?.isEmpty == false ? parts[0] : vehicle
    }

    var vehicleColour: String? {
        let parts = vehicle.split(separator: "·", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard parts.count > 1, !parts[1].isEmpty else { return nil }
        return parts[1]
    }

    /// Stable brand-tinted fill from driver id (presentation avatars without photo assets).
    var avatarTint: Color {
        let palette: [Color] = [
            VuumColor.brand.opacity(0.85),
            Color(red: 0.95, green: 0.55, blue: 0.20),
            Color(red: 0.20, green: 0.55, blue: 0.70),
            Color(red: 0.45, green: 0.40, blue: 0.75),
            Color(red: 0.25, green: 0.60, blue: 0.45),
        ]
        let hash = id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        let idx = abs(hash) % palette.count
        return palette[idx]
    }
}

// MARK: - Avatar

struct DriverAvatarView: View {
    let driver: DriverProfile
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            if let asset = driver.photoAssetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                driver.avatarTint
                Text(driver.initials)
                    .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                    .foregroundStyle(VuumColor.accentOn)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(VuumColor.glassBorder, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Rating

struct DriverRatingLabel: View {
    let rating: Double
    var tripsCompleted: Int?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: compact ? .trailing : .center, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                Text(String(format: "%.2f", rating))
                    .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(VuumColor.primaryText)
            }
            if let tripsCompleted {
                Text("\(tripsCompleted.formatted()) trips")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ratingAccessibility)
    }

    private var ratingAccessibility: String {
        if let tripsCompleted {
            return String(format: "Rated %.2f from %d trips", rating, tripsCompleted)
        }
        return String(format: "Rated %.2f", rating)
    }
}

// MARK: - Plate chip

struct LicensePlateChip: View {
    let plate: String

    var body: some View {
        Text(plate)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(VuumColor.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(VuumColor.chipBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(VuumColor.divider, lineWidth: 1)
            )
            .accessibilityLabel("License plate \(plate)")
    }
}

// MARK: - Driver card

/// Polished driver identity block for matching / en-route / in-trip sheets.
struct DriverCardView: View {
    let driver: DriverProfile
    var etaMinutes: Int? = nil
    var passengerName: String? = nil
    var showTripsCount: Bool = true
    /// Map overlay: hide bio / languages so the sheet stays map-dominant.
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DriverAvatarView(driver: driver, size: compact ? 48 : 56)

            VStack(alignment: .leading, spacing: compact ? 3 : 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(driver.name)
                        .font(.system(size: compact ? 16 : 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                        .lineLimit(1)
                    if let etaMinutes {
                        RideClassETABadge(minutes: etaMinutes, compact: true)
                    }
                }

                Text(driver.vehicleMakeModel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    LicensePlateChip(plate: driver.plate)
                    if let colour = driver.vehicleColour {
                        Text(colour)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                if !compact, !driver.languages.isEmpty {
                    Text(driver.languages.prefix(3).joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if driver.backgroundCheckPassed {
                        trustChip(
                            compact ? "Verified" : "Background check",
                            systemImage: "checkmark.shield.fill"
                        )
                    }
                    trustChip(
                        compact ? "Inspected" : driver.vehicleInspection.title,
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                }

                if !compact {
                    Text(driver.resolvedBio)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(2)
                }

                if let passengerName, !passengerName.isEmpty {
                    Text("Passenger: \(passengerName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }

            Spacer(minLength: 4)

            DriverRatingLabel(
                rating: driver.rating,
                tripsCompleted: showTripsCount && !compact ? driver.tripsCompleted : nil,
                compact: true
            )
        }
        .accessibilityElement(children: .contain)
    }

    private func trustChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VuumColor.brand)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(VuumColor.brand.opacity(0.16), in: Capsule(style: .continuous))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }
}

// MARK: - Contact actions (message / call / share)

struct DriverContactActionsBar: View {
    @EnvironmentObject private var location: RiderLocationManager
    let trip: ActiveTrip
    var unreadChatCount: Int = 0
    var chatEnabled: Bool = true
    var onMessage: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            actionButton(title: "Message", systemImage: "bubble.left.and.bubble.right.fill", action: onMessage)
                .disabled(!chatEnabled)
                .opacity(chatEnabled ? 1 : 0.45)
                .overlay(alignment: .topTrailing) {
                    if unreadChatCount > 0 {
                        Text(unreadChatCount > 9 ? "9+" : "\(unreadChatCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VuumColor.accentOn)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VuumColor.danger, in: Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
                .accessibilityLabel(
                    unreadChatCount > 0
                        ? "Message driver, \(unreadChatCount) unread"
                        : "Message driver"
                )
                .accessibilityHint(chatEnabled ? "Opens chat with your driver" : "Chat unavailable")
                .accessibilityAddTraits(chatEnabled ? [] : .isStaticText)

            if let callURL = DriverCallHelper.telURL(for: trip.driver.phone) {
                Link(destination: callURL) {
                    actionLabel(title: "Call", systemImage: "phone.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Call driver")
                .accessibilityHint("Places a phone call to your driver")
            } else {
                actionButton(title: "Call", systemImage: "phone.fill") {
                    DriverCallHelper.placeCall(to: trip.driver.phone)
                }
                .accessibilityLabel("Call driver")
                .accessibilityHint("Places a phone call to your driver")
            }

            ShareLink(
                item: TripShare.message(for: trip, phase: .inTrip, coordinate: location.latestLocation?.coordinate),
                subject: Text("My Vuum trip"),
                message: Text("Follow my live trip on Vuum")
            ) {
                actionLabel(title: "Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share trip")
            .accessibilityHint("Shares a live trip link with trusted contacts")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(VuumColor.primaryText)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
