import SwiftUI
import UIKit

struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var markOpacity: Double = 0
    @State private var markScale: CGFloat = 0.94
    @State private var markOffset: CGFloat = 8
    @State private var subtitleOpacity: Double = 0

    /// White on dark theme, black on light theme.
    private var titleColor: Color {
        colorScheme == .dark ? .white : .black
    }

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

            VStack(spacing: 10) {
                Text(VuumTheme.displayName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(titleColor)
                    .scaleEffect(markScale)
                    .opacity(markOpacity)
                    .offset(y: markOffset)
                    .accessibilityAddTraits(.isHeader)

                Text("Congo Mobility")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(titleColor.opacity(0.72))
                    .opacity(subtitleOpacity)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                markOpacity = 1
                markScale = 1
                markOffset = 0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.22)) {
                subtitleOpacity = 1
            }
        }
    }

    @ViewBuilder
    private var splashBackdrop: some View {
        if hasSplashBackground {
            Image("SplashBackground")
                .resizable()
                .scaledToFill()
        } else {
            // Brand-safe fallback — no invented artwork; solid field + restrained map mark.
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                Image(systemName: "map")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(titleColor.opacity(0.06))
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
