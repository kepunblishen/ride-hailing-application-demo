import SwiftUI

/// Restrained material surfaces for cards and trip sheets.
/// Prefer solid grouped cards on hubs; use glass sparingly on map-overlaid chrome.
enum VuumGlass {
    static let cardCornerRadius: CGFloat = VuumLayout.radiusPanel
    static let compactCardCornerRadius: CGFloat = VuumLayout.radiusCard

    enum Style {
        /// Subtle elevation for map sheets / floating chrome.
        case panel
        /// Near-flat material — avoid “AI frosted glass” look on dense content.
        case quiet
    }

    static func cardShape(cornerRadius: CGFloat = cardCornerRadius) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct VuumGlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = VuumGlass.cardCornerRadius
    var style: VuumGlass.Style = .panel

    private var borderColor: Color {
        VuumColor.hairline(for: colorScheme)
    }

    private var shadowColor: Color {
        switch style {
        case .panel:
            return VuumColor.glassShadow(for: colorScheme)
        case .quiet:
            return .clear
        }
    }

    private var shadowRadius: CGFloat {
        style == .panel ? 6 : 0
    }

    private var shadowY: CGFloat {
        style == .panel ? 3 : 0
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), style == .panel {
            content
                .glassEffect(.regular, in: VuumGlass.cardShape(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    VuumGlass.cardShape(cornerRadius: cornerRadius)
                        .fill(style == .quiet ? AnyShapeStyle(VuumColor.cardBackground) : AnyShapeStyle(.thinMaterial))
                }
                .overlay {
                    VuumGlass.cardShape(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
    }
}

extension View {
    func VuumGlassSurface(
        cornerRadius: CGFloat = VuumGlass.cardCornerRadius,
        style: VuumGlass.Style = .panel
    ) -> some View {
        modifier(VuumGlassSurfaceModifier(cornerRadius: cornerRadius, style: style))
    }
}
