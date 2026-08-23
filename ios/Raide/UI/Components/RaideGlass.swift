import SwiftUI

/// Apple Materials / Liquid Glass styling for cards and panels.
/// Ported from the Wells scaffold pattern; Raide branding only.
enum RaideGlass {
    static let cardCornerRadius: CGFloat = 20
    static let compactCardCornerRadius: CGFloat = 16

    static func cardShape(cornerRadius: CGFloat = cardCornerRadius) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct RaideGlassSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = RaideGlass.cardCornerRadius

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
                .glassEffect(.regular, in: RaideGlass.cardShape(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RaideGlass.cardShape(cornerRadius: cornerRadius)
                        .fill(.thinMaterial)
                }
                .overlay {
                    RaideGlass.cardShape(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
                .shadow(color: shadowColor, radius: 8, y: 4)
        }
    }
}

extension View {
    func raideGlassSurface(cornerRadius: CGFloat = RaideGlass.cardCornerRadius) -> some View {
        modifier(RaideGlassSurface(cornerRadius: cornerRadius))
    }
}
