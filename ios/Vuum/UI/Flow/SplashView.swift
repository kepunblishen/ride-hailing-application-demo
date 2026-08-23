import SwiftUI
import UIKit

struct SplashView: View {
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
                .font(.system(size: 44, weight: .bold, design: .rounded))
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
        if hasSplashBackground {
            Image("SplashBackground")
                .resizable()
                .scaledToFill()
        } else {
            // Brand-safe fallback — no invented artwork; solid field + restrained map mark.
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
