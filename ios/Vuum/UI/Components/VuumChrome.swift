import SwiftUI

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
                        .tint(VuumColor.brandInk)
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
            .foregroundStyle(VuumColor.brandInk.opacity(enabled ? 1 : 0.45))
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
                        .progressViewStyle(CircularProgressViewStyle(tint: VuumColor.brandInk))
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
            .foregroundStyle(VuumColor.brandInk)
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
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(VuumColor.brandInk)
            .frame(width: size, height: size)
            .background(
                Group {
                    if emphasized {
                        LinearGradient(
                            colors: [VuumColor.brand.opacity(0.32), VuumColor.brand.opacity(0.16)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        VuumColor.brand.opacity(0.20)
                    }
                },
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

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(VuumType.captionSemibold)
                .foregroundStyle(selected ? VuumColor.brandInk : VuumColor.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    selected ? VuumColor.brand.opacity(0.9) : VuumColor.chipBackground,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

struct VuumOfferBadge: View {
    var title: String = "Promo"

    var body: some View {
        Text(title)
            .font(VuumType.micro)
            .foregroundStyle(VuumColor.brandInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VuumColor.brand.opacity(0.92), in: Capsule())
            .accessibilityLabel(title)
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .frame(width: 32, height: 32)
                .background(VuumColor.brand.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                        .foregroundStyle(VuumColor.brandInk)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
