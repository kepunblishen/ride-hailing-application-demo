import ComponentsKit
import SwiftUI

// MARK: - Color

enum VuumColor {
    /// Signal amber — do not restyle casually; brand lock for presentation.
    static let brand = Color(red: 245 / 255, green: 165 / 255, blue: 36 / 255)
    static let brandInk = Color(red: 15 / 255, green: 20 / 255, blue: 25 / 255)

    static let pageBackground = Color(.systemBackground)
    /// Grouped hubs (Services / Activity) — one surface language across tabs.
    static let groupedBackground = Color(.systemGroupedBackground)
    static let sheetBackground = Color(.secondarySystemBackground)
    static let fieldBackground = Color(.secondarySystemBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let divider = Color(.separator)
    static let fieldPlaceholder = Color(.placeholderText)
    static let chipBackground = Color(.tertiarySystemFill)
    static let mapScrim = Color.black.opacity(0.35)
    static let danger = Color(red: 0.86, green: 0.22, blue: 0.28)
    static let success = Color(red: 0.20, green: 0.62, blue: 0.38)

    static var glassBorder: Color {
        Color.primary.opacity(0.08)
    }

    static func glassShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.28)
            : Color.black.opacity(0.05)
    }

    static func hairline(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.primary.opacity(0.06)
    }
}

// MARK: - Layout tokens (hubs + sheets share these)

enum VuumLayout {
    static let pageInset: CGFloat = 16
    static let sectionSpacing: CGFloat = 28
    static let stackSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 12
    static let chipSpacing: CGFloat = 8

    static let radiusChip: CGFloat = 10
    static let radiusControl: CGFloat = 12
    static let radiusCard: CGFloat = 16
    static let radiusPanel: CGFloat = 20
    static let radiusSheet: CGFloat = 24
    static let radiusSearch: CGFloat = 28

    static let iconBadge: CGFloat = 36
    static let iconBadgeLarge: CGFloat = 40
    static let primaryButtonHeight: CGFloat = 54
    static let sheetHandleWidth: CGFloat = 36
    static let sheetHandleHeight: CGFloat = 4
}

// MARK: - Type scale (mobility-product density, not oversized display)

enum VuumType {
    static let hero = Font.system(size: 28, weight: .bold)
    static let title = Font.system(size: 22, weight: .bold)
    static let titleSmall = Font.system(size: 20, weight: .bold)
    static let section = Font.system(size: 22, weight: .bold)
    static let rowTitle = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodySemibold = Font.system(size: 15, weight: .semibold)
    static let callout = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionSemibold = Font.system(size: 13, weight: .semibold)
    static let micro = Font.system(size: 11, weight: .bold)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
}

// MARK: - Theme bootstrap

enum VuumTheme {
    static let brandHex = "#F5A524"
    static let displayName = "Vuum"

    /// Align ComponentsKit accent with Vuum brand (same bootstrap pattern as Wells).
    static func configureComponentsKit() {
        Theme.current.update {
            $0.colors.accent = .init(
                main: .universal(.hex(brandHex)),
                contrast: .universal(.hex("#0F1419")),
                background: .themed(
                    light: .hex("#F4F5F7"),
                    dark: .hex("#1A1F24")
                )
            )
        }
    }
}

// MARK: - View helpers

extension View {
    func VuumPageBackground() -> some View {
        background(VuumColor.pageBackground.ignoresSafeArea())
    }

    func VuumGroupedBackground() -> some View {
        background(VuumColor.groupedBackground.ignoresSafeArea())
    }

    func VuumGlassCard(cornerRadius: CGFloat = VuumGlass.cardCornerRadius) -> some View {
        modifier(VuumGlassCardModifier(cornerRadius: cornerRadius))
    }
}

private struct VuumGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding()
            .VuumGlassSurface(cornerRadius: cornerRadius, style: .panel)
    }
}
