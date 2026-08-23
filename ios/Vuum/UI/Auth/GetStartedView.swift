import SwiftUI

struct GetStartedView: View {
    @ObservedObject var auth: AuthFlowController
    @FocusState private var phoneFocused: Bool
    @State private var showCountries = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 56, height: 56)
                        Text("Vuum")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.top, 28)

                Text(L10n.Auth.getStartedTitle)
                    .font(AuthType.title)
                    .foregroundStyle(AuthPalette.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    .padding(.bottom, AuthLayout.sectionGap)

                Text(L10n.Auth.mobileNumber)
                    .font(AuthType.label)
                    .foregroundStyle(AuthPalette.ink)
                    .padding(.bottom, 8)

                HStack(spacing: AuthLayout.controlSpacing) {
                    AuthCountryCodeButton(
                        flag: auth.countryFlag,
                        dialCode: auth.countryCode,
                        showsDialCode: true
                    ) {
                        showCountries = true
                    }

                    TextField(auth.phonePlaceholder, text: Binding(
                        get: { auth.phoneLocal },
                        set: { auth.applyPhoneInput($0) }
                    ))
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(AuthType.body)
                    .focused($phoneFocused)
                    .authFieldBackground(focused: phoneFocused)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AuthPalette.muted)
                            .padding(.trailing, 12)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(L10n.Auth.mobileNumber)
                    .accessibilityValue(auth.phoneLocal.isEmpty ? L10n.Common.notSet : auth.phoneLocal)
                }

                if let phoneError = auth.phoneError {
                    AuthInlineError(message: phoneError)
                }

                AuthBlackButton(
                    title: L10n.Common.continue,
                    enabled: auth.canContinuePhone,
                    isLoading: auth.phoneSendPhase == .loading
                ) {
                    phoneFocused = false
                    auth.goToOTP()
                }
                .padding(.top, 14)

                AuthOrDivider()
                    .padding(.vertical, 22)

                VStack(spacing: AuthLayout.controlSpacing) {
                    // Visible but inert — no network auth, no toasts.
                    AuthGrayButton(
                        title: L10n.Auth.continueApple,
                        assetIcon: "AuthIconApple",
                        systemIcon: "apple.logo"
                    ) {}
                    AuthGrayButton(
                        title: L10n.Auth.continueGoogle,
                        assetIcon: "AuthIconGoogle",
                        systemIcon: "globe"
                    ) {}
                    AuthGrayButton(
                        title: L10n.Auth.continueEmail,
                        assetIcon: "AuthIconEmail",
                        systemIcon: "envelope.fill"
                    ) {}
                }

                AuthOrDivider()
                    .padding(.vertical, 22)

                Button {} label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .accessibilityHidden(true)
                        Text(L10n.Auth.findAccount)
                            .font(AuthType.bodyMedium)
                    }
                    .foregroundStyle(AuthPalette.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Auth.findAccount)

                Text(L10n.Auth.smsDisclaimer)
                    .font(AuthType.fine)
                    .foregroundStyle(AuthPalette.muted)
                    .padding(.top, AuthLayout.sectionGap)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, AuthLayout.pageInset)
        }
        .background(AuthPalette.page.ignoresSafeArea())
        .sheet(isPresented: $showCountries) {
            AuthCountryPickerSheet(
                isPresented: $showCountries,
                selectedDialCode: auth.countryCode,
                selectedFlag: auth.countryFlag
            ) { country in
                auth.selectCountry(code: country.dialCode, flag: country.flag)
            }
        }
    }
}
