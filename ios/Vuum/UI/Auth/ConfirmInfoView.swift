import SwiftUI

struct ConfirmInfoView: View {
    @ObservedObject var auth: AuthFlowController
    @FocusState private var focused: Field?

    private enum Field {
        case first, last, email
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.Auth.confirmInfo)
                .font(AuthType.title)
                .foregroundStyle(AuthPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AuthLayout.titleTop)

            HStack(spacing: AuthLayout.controlSpacing) {
                nameField(
                    L10n.Auth.firstName,
                    text: Binding(
                        get: { auth.firstName },
                        set: { auth.applyName($0, to: \.firstName) }
                    ),
                    isFocused: focused == .first
                )
                .focused($focused, equals: .first)
                .textContentType(.givenName)

                nameField(
                    L10n.Auth.lastName,
                    text: Binding(
                        get: { auth.lastName },
                        set: { auth.applyName($0, to: \.lastName) }
                    ),
                    isFocused: focused == .last
                )
                .focused($focused, equals: .last)
                .textContentType(.familyName)
            }
            .padding(.top, 26)

            TextField(
                L10n.Auth.emailOptional,
                text: Binding(
                    get: { auth.email },
                    set: { auth.applyEmail($0) }
                )
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(AuthType.body)
            .focused($focused, equals: .email)
            .authFieldBackground(focused: focused == .email)
            .padding(.top, AuthLayout.controlSpacing)
            .accessibilityLabel(L10n.Auth.emailOptional)

            HStack(spacing: AuthLayout.controlSpacing) {
                AuthCountryCodeButton(
                    flag: auth.countryFlag,
                    dialCode: auth.countryCode,
                    showsDialCode: true
                ) {}

                Text("\(auth.countryCode) \(auth.formattedPhoneDisplay)")
                    .font(AuthType.body)
                    .foregroundStyle(AuthPalette.ink)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: AuthLayout.fieldHeight)
                    .background(
                        AuthPalette.fieldFill,
                        in: RoundedRectangle(cornerRadius: AuthLayout.fieldRadius, style: .continuous)
                    )
            }
            .padding(.top, AuthLayout.controlSpacing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(L10n.Auth.mobileNumber) \(auth.countryCode) \(auth.formattedPhoneDisplay)")

            if let profileError = auth.profileError {
                AuthInlineError(message: profileError)
            }

            Spacer(minLength: 16)

            HStack {
                AuthCircleBackButton { auth.goBack() }
                Spacer()
                AuthNextPill(
                    enabled: auth.canSubmitProfile,
                    isLoading: auth.profileSavePhase == .loading
                ) {
                    focused = nil
                    auth.goToWelcome()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, AuthLayout.pageInset)
        .background(AuthPalette.page.ignoresSafeArea())
        .dismissKeyboardOnOutsideTap()
        // No autofocus — keyboard only after the user taps a name/email field.
    }

    private func nameField(_ placeholder: String, text: Binding<String>, isFocused: Bool) -> some View {
        TextField(placeholder, text: text)
            .font(AuthType.body)
            .authFieldBackground(focused: isFocused)
            .accessibilityLabel(placeholder)
            .accessibilityHint(L10n.Auth.nameRequiredHintA11y)
    }
}
