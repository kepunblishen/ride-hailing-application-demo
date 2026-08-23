import SwiftUI
import UIKit

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var markOpacity: Double = 0
    @State private var markScale: CGFloat = 0.94
    @State private var markOffset: CGFloat = 8

    private var hasSplashBackground: Bool {
        UIImage(named: "SplashBackground") != nil
    }

    var body: some View {
        ZStack {
            splashBackdrop
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Text(VuumTheme.displayName)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(VuumColor.primaryText)
                .scaleEffect(markScale)
                .opacity(markOpacity)
                .offset(y: markOffset)
                .accessibilityAddTraits(.isHeader)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                markOpacity = 1
                markScale = 1
                markOffset = 0
            }
        }
    }

    @ViewBuilder
    private var splashBackdrop: some View {
        // Asset catalog supplies light + dark variants; always show the image
        // when present (both schemes). Dark mode gets a light scrim for the mark.
        if hasSplashBackground {
            ZStack {
                Image("SplashBackground")
                    .resizable()
                    .scaledToFill()
                if colorScheme == .dark {
                    Color.black.opacity(0.22)
                }
            }
        } else {
            ZStack {
                VuumColor.pageBackground
                Image(systemName: "map")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(VuumColor.primaryText.opacity(0.06))
            }
        }
    }
}

#Preview("Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    SplashView()
        .preferredColorScheme(.light)
}
