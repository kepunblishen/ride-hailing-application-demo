import ComponentsKit
import SwiftUI

enum VuumColor {
    /// Signal amber
    static let brand = Color(red: 245 / 255, green: 165 / 255, blue: 36 / 255)
    static let brandInk = Color(red: 15 / 255, green: 20 / 255, blue: 25 / 255)
    static let pageBackground = Color(.systemBackground)
    static let sheetBackground = Color(.secondarySystemBackground)
    static let fieldBackground = Color(.secondarySystemBackground)
    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let divider = Color(.separator)
    static let fieldPlaceholder = Color(.placeholderText)
    static let chipBackground = Color(.tertiarySystemFill)
    static let mapScrim = Color.black.opacity(0.35)

    static var glassBorder: Color {
        Color.primary.opacity(0.08)
    }

    static func glassShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.35)
            : Color.black.opacity(0.06)
    }
}

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

extension View {
    func VuumPageBackground() -> some View {
        background(VuumColor.pageBackground.ignoresSafeArea())
    }

    func VuumGlassCard(cornerRadius: CGFloat = VuumGlass.cardCornerRadius) -> some View {
        modifier(VuumGlassCard(cornerRadius: cornerRadius))
    }
}

private struct VuumGlassCard: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding()
            .VuumGlassSurface(cornerRadius: cornerRadius)
    }
}
