import SwiftUI

struct AuthFlowView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var auth = AuthFlowController()

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
        .animation(.easeInOut(duration: 0.25), value: auth.step)
    }
}
