import ComponentsKit
import SwiftUI

// MARK: - Color

enum VuumColor {
    /// Interactive blue-600 — primary actions and emphasis (replaces amber).
    static let brand = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255) // blue-600 — primary actions
    static let brandInk = Color(red: 15 / 255, green: 20 / 255, blue: 25 / 255)

    /// Tailwind blue-600 — primary accents, links, focus rings.
    static let accent = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255) // #2563EB
    static let accentBright = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255) // #3B82F6 blue-500
    static let accentOn = Color.white

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
    static let hero = Font.system(size: 28, weight: .semibold)
    static let title = Font.system(size: 22, weight: .semibold)
    static let titleSmall = Font.system(size: 20, weight: .semibold)
    static let section = Font.system(size: 22, weight: .semibold)
    static let rowTitle = Font.system(size: 16, weight: .semibold)
    static let body = Font.system(size: 15, weight: .regular)
    static let bodySemibold = Font.system(size: 15, weight: .semibold)
    static let callout = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let captionSemibold = Font.system(size: 13, weight: .semibold)
    static let micro = Font.system(size: 11, weight: .semibold)
    static let button = Font.system(size: 17, weight: .semibold)
}

// MARK: - Theme bootstrap

enum VuumTheme {
    static let brandHex = "#2563EB"
    static let accentHex = "#2563EB"
    static let accentBrightHex = "#3B82F6"
    static let displayName = "Vuum"

    /// Align ComponentsKit accent with interactive blue (auth + controls).
    static func configureComponentsKit() {
        Theme.current.update {
            $0.colors.accent = .init(
                main: .universal(.hex(accentHex)),
                contrast: .universal(.hex("#FFFFFF")),
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
