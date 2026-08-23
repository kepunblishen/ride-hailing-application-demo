import SwiftUI
import UIKit

// MARK: - Buttons

struct VuumPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var showArrow: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(VuumColor.accentOn)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        if showArrow {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .font(VuumType.button)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: VuumLayout.primaryButtonHeight)
            .foregroundStyle(VuumColor.accentOn.opacity(enabled ? 1 : 0.55))
            .background(
                VuumColor.brand.opacity(enabled ? 1 : 0.45),
                in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous)
            )
        }
        .buttonStyle(VuumPressStyle())
        .disabled(isLoading || !enabled)
    }
}

struct VuumSecondaryButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VuumType.bodySemibold)
                .foregroundStyle(VuumColor.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: VuumLayout.primaryButtonHeight)
                .background(
                    VuumColor.chipBackground,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                        .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
                }
        }
        .buttonStyle(VuumPressStyle())
    }
}

/// Capsule CTA — prefer `VuumPrimaryButton` on hubs; keep capsule for auth/legacy Wells parity.
struct VuumPrimaryCapsuleButton: View {
    let title: String
    var isLoading: Bool = false
    var showArrow: Bool = false
    let action: () -> Void

    private var fillColor: Color {
        isLoading ? VuumColor.brand.opacity(0.85) : VuumColor.brand
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(VuumColor.accentOn)
                } else {
                    HStack(spacing: 8) {
                        Text(title)
                        if showArrow {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(VuumColor.accentOn)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(fillColor, in: Capsule())
        }
        .buttonStyle(VuumPressStyle())
        .disabled(isLoading)
    }
}

struct VuumPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// Circular material chip for map-flow back/close and sheet leading dismiss.
struct VuumCircleChromeButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
                .frame(width: size, height: size)
                .VuumChromeMaterialBackground(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Top-leading map overlay for pushed ride-flow screens (destination → choose → search).
struct VuumFlowBackChrome: View {
    var systemImage: String = "chevron.left"
    var accessibilityLabel: String = L10n.Common.back
    let action: () -> Void

    var body: some View {
        // Chip only — place via `.overlay(alignment: .topLeading)` so it does not
        // compete with `TripMapLayer` for ZStack height or steal map gestures.
        VuumCircleChromeButton(
            systemImage: systemImage,
            accessibilityLabel: accessibilityLabel,
            action: action
        )
        .padding(.leading, 16)
        .safeAreaPadding(.top, 8)
    }
}

/// Plan-your-ride map top chrome — adaptive material back chip + brand-blue location pill.
/// Pill sets pickup from GPS via `RiderLocationManager` / `updatePickup`,
/// not a system share sheet.
struct VuumPlanRideMapChrome: View {
    var backSystemImage: String = "arrow.left"
    var backAccessibilityLabel: String = L10n.Common.back
    var locationTitle: String = L10n.Destination.shareCurrentLocation
    var onBack: () -> Void
    var onUseCurrentLocation: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let chipSize: CGFloat = 48

    var body: some View {
        // Intrinsic height only — a full-screen Spacer overlay would sit above the
        // bottom sheet and steal / confuse drag-to-resize hits.
        HStack(alignment: .center, spacing: 12) {
            planRideBackChip

            Spacer(minLength: 4)

            planRideLocationPill

            Spacer(minLength: 4)

            // Mirror the back chip so the pill stays visually centered (HTML spacer).
            Color.clear
                .frame(width: chipSize, height: chipSize)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .safeAreaPadding(.top, 8)
    }

    private var planRideBackChip: some View {
        Button(action: onBack) {
            Image(systemName: backSystemImage)
                .font(.system(size: 18, weight: .semibold))
                // HTML mock: solid white chip + dark glyph (readable on light and dark maps).
                .foregroundStyle(Color.black.opacity(0.85))
                .frame(width: chipSize, height: chipSize)
                .background(Color.white, in: Circle())
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 8, y: 3)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(backAccessibilityLabel)
    }

    private var planRideLocationPill: some View {
        Button(action: onUseCurrentLocation) {
            HStack(spacing: 8) {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(locationTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(VuumColor.accentOn)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(VuumColor.brand, in: Capsule())
            .shadow(color: Color.black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locationTitle)
        .accessibilityHint("Sets pickup to your GPS position and recenters the map")
    }
}

// MARK: - Sheet chrome (map-overlaid trip sheets)

struct VuumSheetChrome<Content: View>: View {
    var title: String?
    /// Prefer `.quiet` for dense map sheets (choose-ride) so glass doesn’t overpower the map.
    var glassStyle: VuumGlass.Style = .panel
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: VuumLayout.stackSpacing) {
            VuumSheetHandle()

            if let title {
                Text(title)
                    .font(VuumType.titleSmall)
                    .foregroundStyle(VuumColor.primaryText)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .VuumGlassSurface(cornerRadius: VuumLayout.radiusSheet, style: glassStyle)
    }
}

struct VuumSheetHandle: View {
    var body: some View {
        Capsule()
            .fill(VuumColor.divider)
            .frame(width: VuumLayout.sheetHandleWidth, height: VuumLayout.sheetHandleHeight)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

/// 1pt rule that stays visible on dark sheet / glass surfaces (prefer over `Divider`).
struct VuumHairline: View {
    @Environment(\.colorScheme) private var colorScheme
    var horizontalInset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(VuumColor.hairline(for: colorScheme))
            .frame(height: 1)
            .padding(.horizontal, horizontalInset)
            .accessibilityHidden(true)
    }
}

// MARK: - Hub primitives (Services / Activity / Account / Payments)

struct VuumSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(VuumType.section)
                .foregroundStyle(VuumColor.primaryText)
            if let subtitle {
                Text(subtitle)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct VuumIconBadge: View {
    let systemName: String
    var size: CGFloat = VuumLayout.iconBadge
    var cornerRadius: CGFloat = VuumLayout.radiusChip
    var emphasized: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(emphasized ? VuumColor.brand : VuumColor.primaryText)
            .frame(width: size, height: size)
            .background(
                VuumColor.chipBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Plan-your-ride / Destination list row: neutral circle + title/subtitle hierarchy.
/// Glyph may be brand or gray — never a blue filled blob behind the icon.
struct VuumDestinationPlaceRowContent: View {
    let title: String
    let subtitle: String
    let systemImage: String
    /// Brand glyph for Home / Work / favorites; gray for recent and generic pins.
    var emphasizedGlyph: Bool = false
    var showsChevron: Bool = false
    var verticalPadding: CGFloat = 16

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(emphasizedGlyph ? VuumColor.brand : VuumColor.secondaryText)
                .frame(width: 40, height: 40)
                .background(VuumColor.chipBackground, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
    }
}


/// Solid grouped card — default hub surface (not frosted glass).
struct VuumHubCard<Content: View>: View {
    var padding: CGFloat = 0
    var cornerRadius: CGFloat = VuumLayout.radiusCard
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(padding)
            .background(
                VuumColor.cardBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
            }
    }
}

struct VuumFilterChip: View {
    let title: String
    var selected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
                .overlay {
                    Capsule()
                        .strokeBorder(
                            selected ? Color.clear : VuumColor.hairline(for: colorScheme),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

/// Solid promo / plan capsule — high contrast in light and dark (no washed opacity fills).
struct VuumOfferBadge: View {
    enum Kind {
        /// Red “Promo” / “% off” style.
        case promo
        /// Blue informational pill (e.g. “Plan”).
        case plan
    }

    var title: String = "Promo"
    var kind: Kind = .promo
    /// Tighter padding for icon overlays (Home “For you” tiles).
    var compact: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(compact ? .system(size: 9, weight: .bold) : VuumType.micro)
            .foregroundStyle(Color.white)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(fill, in: Capsule())
            .accessibilityLabel(title)
    }

    private var fill: Color {
        switch kind {
        case .promo:
            // Solid red — slightly brighter in dark so it doesn’t look washed on dark tiles.
            return colorScheme == .dark
                ? Color(red: 0.92, green: 0.30, blue: 0.34)
                : Color(red: 0.86, green: 0.18, blue: 0.22)
        case .plan:
            return colorScheme == .dark ? VuumColor.accentBright : VuumColor.brand
        }
    }
}

struct VuumHubRowLabel: View {
    let title: String
    let systemImage: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: VuumLayout.rowSpacing) {
            VuumIconBadge(systemName: systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                if let subtitle {
                    Text(subtitle)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
    }
}

/// Recoverable banner when a system permission blocks a core ride or safety feature.
struct PermissionDeniedBanner: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String = "Open Settings"
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .frame(width: 32, height: 32)
                .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(VuumColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.brand)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            VuumColor.cardBackground,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Destination / place search field

/// Shared pickup & destination search chrome — visible fill in dark mode (not sheet-matched gray),
/// readable placeholders, brand caret, and a clear control.
struct VuumDestinationSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isBusy: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    /// Light: systemGray6 ≈ gray-100. Dark: tertiary fill so the field stays visible on sheets.
    /// Prefer this over `VuumColor.fieldBackground` when the parent is already `secondarySystemBackground`.
    static var searchFill: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? .tertiarySystemFill
                : .systemGray6
        })
    }

    private var fill: Color { Self.searchFill }

    private var placeholderColor: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.48)
            : Color.primary.opacity(0.40)
    }

    private var clearIconColor: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.55)
            : VuumColor.secondaryText.opacity(0.85)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VuumColor.secondaryText)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder).foregroundStyle(placeholderColor)
            )
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(VuumColor.primaryText)
            .tint(VuumColor.brand)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .accessibilityLabel(placeholder)

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .tint(VuumColor.secondaryText)
            } else if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(clearIconColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Auth.clearSearch)
            }
        }
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Trip endpoints connector (dot – line – square)

/// Vertical pickup → destination rail matching Plan your ride / Destination Search HTML:
/// filled circle (pickup), stem, rounded square (dropoff). Adaptive light/dark colors.
struct VuumTripEndpointsConnector: View {
    enum Style {
        /// High-contrast markers (Plan your ride sheet).
        case plan
        /// Muted pickup + brand dropoff (Destination Search).
        case search
    }

    var style: Style = .search
    /// Intermediate stop dots between pickup and destination (multi-stop).
    var intermediateStops: Int = 0
    var markerSize: CGFloat = 8
    var stemWidth: CGFloat = 2

    @Environment(\.colorScheme) private var colorScheme

    private var pickupColor: Color {
        switch style {
        case .plan:
            return VuumColor.primaryText
        case .search:
            return colorScheme == .dark
                ? Color.primary.opacity(0.55)
                : VuumColor.secondaryText
        }
    }

    private var dropoffColor: Color {
        switch style {
        case .plan:
            return VuumColor.primaryText
        case .search:
            return VuumColor.brand
        }
    }

    private var stemColor: Color {
        switch style {
        case .plan:
            return colorScheme == .dark
                ? Color.primary.opacity(0.35)
                : Color.primary.opacity(0.28)
        case .search:
            return colorScheme == .dark
                ? Color.primary.opacity(0.28)
                : VuumColor.opaqueSeparator.opacity(0.85)
        }
    }

    private var stopColor: Color {
        colorScheme == .dark
            ? Color.primary.opacity(0.45)
            : VuumColor.secondaryText.opacity(0.9)
    }

    /// Halo so markers read clearly when they sit on the stem (Plan your ride rings).
    private var ringColor: Color {
        colorScheme == .dark
            ? VuumColor.sheetBackground
            : Color.white
    }

    var body: some View {
        VStack(spacing: 0) {
            markerRing {
                Circle()
                    .fill(pickupColor)
                    .frame(width: markerSize, height: markerSize)
            }
            .accessibilityHidden(true)

            stem

            ForEach(0..<max(0, intermediateStops), id: \.self) { _ in
                markerRing {
                    Circle()
                        .fill(stopColor)
                        .frame(width: markerSize * 0.75, height: markerSize * 0.75)
                }
                .accessibilityHidden(true)
                stem
            }

            markerRing(isSquare: true) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(dropoffColor)
                    .frame(width: markerSize, height: markerSize)
            }
            .accessibilityHidden(true)
        }
        .frame(width: max(markerSize + 4, stemWidth + 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route from pickup to destination")
    }

    private var stem: some View {
        Rectangle()
            .fill(stemColor)
            .frame(width: stemWidth)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func markerRing<Content: View>(isSquare: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(1.5)
            .background {
                if isSquare {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(ringColor)
                } else {
                    Circle().fill(ringColor)
                }
            }
    }
}

/// Lays a `VuumTripEndpointsConnector` beside stacked pickup / destination rows.
/// Pass one child view per endpoint (and optional stop rows) so the rail stretches with the stack.
/// Uses vertical `fixedSize` so the flexible stem cannot inflate row heights (Where to? ~3× taller bug).
struct VuumTripEndpointsStack<Content: View>: View {
    var style: VuumTripEndpointsConnector.Style = .search
    var intermediateStops: Int = 0
    var spacing: CGFloat = 10
    /// Vertical inset so circle/square sit near field centers (~48pt rows).
    var railVerticalInset: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VuumTripEndpointsConnector(
                style: style,
                intermediateStops: intermediateStops
            )
            .padding(.vertical, railVerticalInset)

            VStack(spacing: spacing) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }
}

/// Dim / read-only endpoint row (pickup on Destination Search).
struct VuumEndpointSummaryField: View {
    let title: String
    var emphasized: Bool = false
    var action: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var fill: Color {
        if emphasized {
            return VuumDestinationSearchField.searchFill
        }
        return colorScheme == .dark
            ? Color.primary.opacity(0.06)
            : Color.primary.opacity(0.04)
    }

    private var foreground: Color {
        emphasized ? VuumColor.primaryText : VuumColor.secondaryText
    }

    var body: some View {
        let label = Text(title)
            .font(.system(size: 16, weight: emphasized ? .semibold : .medium))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .frame(height: VuumLayout.endpointRowHeight)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityLabel(title)
    }
}

/// Bordered From/To card used by Plan your ride (black outline, internal divider).
struct VuumPlanRideEndpointsCard<Content: View>: View {
    var intermediateStops: Int = 0
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VuumTripEndpointsStack(
            style: .plan,
            intermediateStops: intermediateStops,
            spacing: 0,
            railVerticalInset: 14
        ) {
            content()
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
        .padding(.leading, 4)
        .background(
            colorScheme == .dark
                ? VuumColor.chipBackground
                : Color(uiColor: .systemGray6),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VuumColor.hairline(for: colorScheme), lineWidth: colorScheme == .dark ? 1 : 2)
        }
    }
}

/// Hairline between From / To inside `VuumPlanRideEndpointsCard`.
struct VuumPlanRideEndpointsDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(VuumColor.hairline(for: colorScheme))
            .frame(height: 1)
            .padding(.leading, 0)
            .accessibilityHidden(true)
    }
}
