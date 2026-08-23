import SwiftUI

/// Apple Materials / Liquid Glass styling for cards and panels.
/// Ported from the Wells scaffold pattern; Vuum branding only.
enum VuumGlass {
    static let cardCornerRadius: CGFloat = 20
    static let compactCardCornerRadius: CGFloat = 16

    static func cardShape(cornerRadius: CGFloat = cardCornerRadius) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct VuumGlassSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = VuumGlass.cardCornerRadius

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.primary.opacity(0.08)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.35)
            : Color.black.opacity(0.06)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: VuumGlass.cardShape(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    VuumGlass.cardShape(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                }
                .overlay {
                    VuumGlass.cardShape(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: 8, y: 4)
        }
    }
}

extension View {
    func VuumGlassSurface(cornerRadius: CGFloat = VuumGlass.cardCornerRadius) -> some View {
        modifier(VuumGlassSurface(cornerRadius: cornerRadius))
    }
}
