import SwiftUI

struct WelcomeView: View {
    @ObservedObject var auth: AuthFlowController
    var onFinished: () -> Void

    @State private var showArrow = false
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 10

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Text(L10n.Auth.welcome)
                .font(AuthType.hero)
                .foregroundStyle(AuthPalette.ink)
                .opacity(titleOpacity)
                .offset(y: titleOffset)
                .accessibilityAddTraits(.isHeader)

            Text(L10n.Auth.customizing)
                .font(AuthType.body)
                .foregroundStyle(AuthPalette.muted)
                .opacity(titleOpacity)
                .accessibilityLabel(L10n.Auth.customizing)

            Image(systemName: "arrow.right")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(AuthPalette.ink)
                .opacity(showArrow ? 1 : 0)
                .offset(x: showArrow ? 0 : -8)
                .padding(.top, 32)
                .accessibilityHidden(true)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(AuthPalette.page.ignoresSafeArea())
        .task {
            withAnimation(.easeOut(duration: 0.4)) {
                titleOpacity = 1
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.25)) {
                showArrow = true
            }
            try? await Task.sleep(for: .seconds(1.6))
            onFinished()
        }
    }
}
