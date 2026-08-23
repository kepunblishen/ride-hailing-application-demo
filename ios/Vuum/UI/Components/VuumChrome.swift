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

// MARK: - Sheet chrome (map-overlaid trip sheets)

struct VuumSheetChrome<Content: View>: View {
    var title: String?
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
        .VuumGlassSurface(cornerRadius: VuumLayout.radiusSheet, style: .panel)
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
                emphasized ? VuumColor.brand.opacity(0.18) : VuumColor.chipBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .accessibilityHidden(true)
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
                .background(VuumColor.brand.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
