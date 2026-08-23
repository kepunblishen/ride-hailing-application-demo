import ComponentsKit
import SwiftUI
import UIKit

// MARK: - Color

/// Semantic palette for signed-in + shared chrome. Prefer these over raw `Color.black` / `Color.white`.
///
/// **Use for body UI**
/// - `pageBackground` / `groupedBackground` — screen roots
/// - `primaryText` / `secondaryText` / `fieldPlaceholder` — copy
/// - `cardBackground` / `sheetBackground` / `fieldBackground` / `chipBackground` — surfaces
/// - `border` / `divider` / `separator` — rules
/// - `brand` — interactive accent, tab tint, links, primary CTA fill
/// - `accentOn` — label on solid `brand` / `emphasizedFill`
/// - `brandInk` — ink on brand *washes* (e.g. `brand.opacity(0.2)` chips); adaptive
/// - `emphasizedFill` — solid dark/blue fill that pairs with `accentOn` (not adaptive ink)
/// - `danger` / `destructive` / `success` — status
enum VuumColor {
    // MARK: Brand (readable in light + dark)

    /// Interactive blue — primary actions, tab tint, links. Prefer over `brandInk` for chrome tint.
    static let brand = dynamic(
        light: UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1),  // #2563EB
        dark: UIColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255, alpha: 1)   // #3B82F6 — slightly brighter on dark
    )

    /// High-contrast ink for text/icons on brand washes. Light: near-black. Dark: cool near-white.
    /// Do **not** use as a solid button fill with white labels — use `emphasizedFill` + `accentOn`.
    static let brandInk = dynamic(
        light: UIColor(red: 15 / 255, green: 20 / 255, blue: 25 / 255, alpha: 1),
        dark: UIColor(red: 232 / 255, green: 238 / 255, blue: 248 / 255, alpha: 1)
    )

    /// Solid fill for primary/emphasis controls that expect `accentOn` (white) labels.
    /// Light: charcoal. Dark: brand blue (keeps white labels readable).
    static let emphasizedFill = dynamic(
        light: UIColor(red: 15 / 255, green: 20 / 255, blue: 25 / 255, alpha: 1),
        dark: UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
    )

    /// Tailwind blue-600 / blue-500 — accents, links, focus rings (aliases of brand family).
    static let accent = brand
    static let accentBright = dynamic(
        light: UIColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255, alpha: 1),  // #3B82F6
        dark: UIColor(red: 96 / 255, green: 165 / 255, blue: 250 / 255, alpha: 1)   // #60A5FA
    )
    /// Label color on solid brand / emphasized fills.
    static let accentOn = Color.white

    // MARK: Surfaces (system dynamic)

    static let pageBackground = Color(.systemBackground)
    /// Grouped hubs (Services / Activity) — one surface language across tabs.
    static let groupedBackground = Color(.systemGroupedBackground)
    static let sheetBackground = Color(.secondarySystemBackground)
    static let fieldBackground = Color(.secondarySystemBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let chipBackground = Color(.tertiarySystemFill)

    // MARK: Text

    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)
    static let fieldPlaceholder = Color(.placeholderText)

    // MARK: Borders / separators

    static let divider = Color(.separator)
    static let separator = divider
    static let border = Color(.separator)
    static let opaqueSeparator = Color(.opaqueSeparator)

    // MARK: Status

    static let danger = dynamic(
        light: UIColor(red: 0.86, green: 0.22, blue: 0.28, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.42, blue: 0.42, alpha: 1)
    )
    static let destructive = danger
    static let success = dynamic(
        light: UIColor(red: 0.20, green: 0.62, blue: 0.38, alpha: 1),
        dark: UIColor(red: 0.40, green: 0.84, blue: 0.57, alpha: 1)
    )

    /// Map overlay dimmer — intentionally non-adaptive (sits on map imagery).
    static let mapScrim = Color.black.opacity(0.35)

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

    // MARK: Dynamic helper

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
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

    // Map hosts: bottom sheets leave ~45–60% of the map visible.
    static let mapSheetMinFraction: CGFloat = 0.40
    static let mapSheetPreferredFraction: CGFloat = 0.48
    static let mapSheetMaxFraction: CGFloat = 0.55

    /// Cap for map-overlaid bottom sheets (fraction of host height, clamped 40–55%).
    static func mapSheetMaxHeight(in hostHeight: CGFloat, fraction: CGFloat = mapSheetPreferredFraction) -> CGFloat {
        let clamped = min(mapSheetMaxFraction, max(mapSheetMinFraction, fraction))
        return hostHeight * clamped
    }
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
                main: .themed(
                    light: .hex(accentHex),
                    dark: .hex(accentBrightHex)
                ),
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
