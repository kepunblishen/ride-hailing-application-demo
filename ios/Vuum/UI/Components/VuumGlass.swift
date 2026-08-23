import SwiftUI

/// Restrained material surfaces for cards and trip sheets.
/// Prefer solid grouped cards on hubs; use glass sparingly on map-overlaid chrome.
/// Materials thicken in dark mode so label contrast survives map / photo washout.
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

    /// Primary panels / sheets — opaque enough for `primaryText` over maps.
    static func adaptiveMaterial(for colorScheme: ColorScheme) -> Material {
        colorScheme == .dark ? .thickMaterial : .regularMaterial
    }

    /// Compact floating chrome (back chips, map controls).
    static func chromeMaterial(for colorScheme: ColorScheme) -> Material {
        colorScheme == .dark ? .regularMaterial : .thinMaterial
    }

    /// Solid underlay so frosted glass never reads as pure white / washed gray.
    static func panelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground).opacity(0.78)
            : Color(.secondarySystemGroupedBackground).opacity(0.62)
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
        // Liquid Glass can wash out labels in dark mode — keep adaptive materials there.
        if #available(iOS 26.0, *), style == .panel, colorScheme == .light {
            content
                .glassEffect(.regular, in: VuumGlass.cardShape(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    ZStack {
                        if style == .quiet {
                            VuumGlass.cardShape(cornerRadius: cornerRadius)
                                .fill(VuumColor.cardBackground)
                        } else {
                            VuumGlass.cardShape(cornerRadius: cornerRadius)
                                .fill(VuumGlass.panelFill(for: colorScheme))
                            VuumGlass.cardShape(cornerRadius: cornerRadius)
                                .fill(VuumGlass.adaptiveMaterial(for: colorScheme))
                        }
                    }
                }
                .overlay {
                    VuumGlass.cardShape(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
        }
    }
}

/// Floating map chips / compact chrome — denser than `ultraThinMaterial`.
private struct VuumChromeMaterialFillModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(VuumGlass.chromeMaterial(for: colorScheme))
    }
}

private struct VuumChromeMaterialInShapeModifier<S: Shape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S

    func body(content: Content) -> some View {
        content.background(VuumGlass.chromeMaterial(for: colorScheme), in: shape)
    }
}

extension View {
    func VuumGlassSurface(
        cornerRadius: CGFloat = VuumGlass.cardCornerRadius,
        style: VuumGlass.Style = .panel
    ) -> some View {
        modifier(VuumGlassSurfaceModifier(cornerRadius: cornerRadius, style: style))
    }

    /// Prefer over raw `ultraThinMaterial` so dark-mode labels stay readable.
    func VuumChromeMaterialBackground() -> some View {
        modifier(VuumChromeMaterialFillModifier())
    }

    func VuumChromeMaterialBackground<S: Shape>(in shape: S) -> some View {
        modifier(VuumChromeMaterialInShapeModifier(shape: shape))
    }
}
