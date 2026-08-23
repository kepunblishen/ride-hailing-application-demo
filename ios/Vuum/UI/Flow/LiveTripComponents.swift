import SwiftUI

// MARK: - Searching pulse

/// Concentric rings used on the matching sheet — state communication, not decoration.
struct SearchingPulseView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("vuum.a11y.reduceMotion") private var appReduceMotion = false
    @State private var pulse = false

    private var reduceMotion: Bool {
        systemReduceMotion || appReduceMotion
    }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(VuumColor.brand.opacity(0.35 - Double(index) * 0.1), lineWidth: 2)
                    .frame(width: 56 + CGFloat(index) * 28, height: 56 + CGFloat(index) * 28)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.08 : 0.92))
                    .opacity(reduceMotion ? (0.55 - Double(index) * 0.12) : (pulse ? 0.35 : 0.9))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.35)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.18),
                        value: pulse
                    )
            }
            Image(systemName: "car.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(VuumColor.accentOn)
                .frame(width: 52, height: 52)
                .background(VuumColor.brand, in: Circle())
        }
        .frame(height: reduceMotion ? 96 : 120)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Live ETA

struct LiveETABadge: View {
    let minutes: Int
    /// Short status under the duration (e.g. ETA / left). Duration already includes “min”.
    var caption: String = "ETA"
    var emphasize: Bool = true

    var body: some View {
        VStack(spacing: 2) {
            Text(TripGeo.formatDuration(minutes: max(minutes, 0)))
                .font(.system(size: emphasize ? 28 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(VuumColor.brand)
                .monospacedDigit()
            Text(caption)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
                .textCase(.uppercase)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(TripGeo.formatDuration(minutes: max(minutes, 0))) \(caption)")
    }
}

// MARK: - Driver card

struct LiveDriverCard: View {
    let driver: DriverProfile
    var showPIN: String? = nil
    /// Prefer header `LiveETABadge` on map overlays; pass only when card owns ETA.
    var etaMinutes: Int? = nil
    var passengerName: String? = nil
    var compact: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DriverCardView(
                driver: driver,
                etaMinutes: etaMinutes,
                passengerName: passengerName,
                compact: compact
            )
            if let showPIN {
                HStack(spacing: 8) {
                    Text("Trip PIN")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                    Text(showPIN)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(VuumColor.brandInk)
                    Spacer()
                    Text("Share with driver at pickup")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(10)
                .background(VuumColor.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// MARK: - Quick actions

struct LiveTripActionChip: View {
    let title: String
    let systemImage: String
    var badge: Int = 0
    var tint: Color = VuumColor.primaryText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(VuumColor.chipBackground, in: Circle())
                    if badge > 0 {
                        Text(badge > 9 ? "9+" : "\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VuumColor.accentOn)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VuumColor.danger, in: Capsule())
                            .offset(x: 6, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge > 0 ? "\(title), \(badge) unread" : title)
    }
}

// MARK: - SOS pill

struct LiveTripSOSButton: View {
    let helpSent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(helpSent ? "HELP SENT" : "SOS")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(VuumColor.accentOn)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(helpSent ? VuumColor.brand : VuumColor.danger)
                        .shadow(color: VuumColor.danger.opacity(0.3), radius: 8, y: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(helpSent ? "Help already requested" : "Emergency SOS")
        .accessibilityHint(helpSent ? "Opens safety status" : "Requests emergency help for this trip")
    }
}

// MARK: - Boarding PIN

struct BoardingPINPanel: View {
    let tripPIN: String
    @Binding var entry: String
    var rejected: Bool
    /// When false (Safety settings), boarding can continue without typing the PIN.
    var requirePIN: Bool = true
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Verify your ride")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(
                requirePIN
                    ? "Share this PIN with your driver, then confirm boarding."
                    : "Confirm boarding when you’re ready. PIN verification is optional in your Safety settings."
            )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
                .multilineTextAlignment(.center)

            Text(tripPIN)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .tracking(10)
                .foregroundStyle(VuumColor.primaryText)
                .padding(.vertical, 4)
                .accessibilityLabel("Trip PIN \(tripPIN)")

            if requirePIN {
                TextField("Enter PIN", text: $entry)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if rejected {
                    Text("PIN doesn’t match — check with your driver")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.danger)
                }
            }

            VuumPrimaryButton(title: "Confirm boarding", action: onConfirm)
                .disabled(requirePIN && entry.count < 4)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(VuumColor.chipBackground.opacity(0.65), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Progress

struct LiveTripProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VuumColor.chipBackground)
                Capsule()
                    .fill(VuumColor.brand)
                    .frame(width: max(8, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Trip progress")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
