import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var auth = AuthFlowController()
    @ObservedObject private var authLocale = AuthLocale.shared

    var body: some View {
        Group {
            switch auth.step {
            case .getStarted:
                GetStartedView(auth: auth)
            case .otp:
                OTPVerifyView(auth: auth)
            case .terms:
                TermsAgreeView(auth: auth)
            case .confirmInfo:
                ConfirmInfoView(auth: auth)
            case .welcome:
                WelcomeView(auth: auth) {
                    session.completeSignIn(
                        countryCode: auth.countryCode,
                        mobileNumber: auth.normalizedPhoneDigits,
                        firstName: auth.firstName,
                        lastName: auth.lastName,
                        email: auth.email
                    )
                }
            }
        }
        // Remount visible step when language changes so every auth screen refreshes copy.
        .id(authLocale.language)
        .environmentObject(authLocale)
        .animation(.easeInOut(duration: 0.25), value: auth.step)
        .animation(.easeInOut(duration: 0.2), value: authLocale.language)
        .onChange(of: authLocale.language) { _, _ in
            auth.relocalizePresentedErrors()
        }
        // Activate without a matching onDisappear — language `.id` remounts must not clear isActive.
        .dismissKeyboardOnOutsideTap()
        .onAppear { authLocale.isActive = true }
    }
}
