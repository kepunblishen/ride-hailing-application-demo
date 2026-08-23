import SwiftUI

struct OTPVerifyView: View {
    @ObservedObject var auth: AuthFlowController
    @FocusState private var focusedIndex: Int?
    @State private var showBackup = false
    @State private var backupCode = ""

    private var resendEnabled: Bool { auth.canResendOTP }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.Auth.otpTitle)
                    .font(AuthType.title)
                    .foregroundStyle(AuthPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(String(format: L10n.Auth.otpSubtitle, auth.maskedPhoneForOTP))
                    .font(AuthType.body)
                    .foregroundStyle(AuthPalette.muted)
                    .padding(.top, 10)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AuthLayout.otpBoxSpacing) {
                    ForEach(0..<4, id: \.self) { index in
                        otpBox(index: index)
                            .frame(maxWidth: .infinity)
                            .frame(height: AuthLayout.otpBoxHeight)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(L10n.Auth.verificationCodeA11y)

                if let otpError = auth.otpError {
                    AuthInlineError(message: otpError)
                }

                resendRow
                    .padding(.top, 22)

                Button {
                    backupCode = ""
                    showBackup = true
                } label: {
                    Text(L10n.Auth.backupCode)
                        .font(AuthType.caption)
                        .foregroundStyle(AuthPalette.muted)
                        .underline(true, color: AuthPalette.muted.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .accessibilityLabel(L10n.Auth.backupCode)
            }
            .padding(.horizontal, AuthLayout.pageInset)
            .padding(.top, 8)

            Spacer(minLength: 16)

            AuthBlackButton(
                title: L10n.Auth.verify,
                enabled: auth.canSubmitOTP,
                isLoading: auth.otpVerifyPhase == .loading
            ) {
                focusedIndex = nil
                auth.goToTerms()
            }
            .padding(.horizontal, AuthLayout.pageInset)
            .padding(.bottom, 12)
        }
        .background(AuthPalette.page.ignoresSafeArea())
        .dismissKeyboardOnOutsideTap()
        .onChange(of: auth.otpDigits) { _, _ in
            advanceFocusIfNeeded()
        }
        .task {
            // Fill the expected local code after a short pause if the rider has not typed yet.
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            auth.autofillExpectedOTPIfEmpty()
        }
        .sheet(isPresented: $showBackup) {
            backupSheet
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                auth.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AuthPalette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Common.back)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: AuthLayout.topBarHeight)
    }

    private var resendRow: some View {
        HStack(spacing: 4) {
            Text(L10n.Auth.resendPrompt)
                .font(AuthType.body)
                .foregroundStyle(AuthPalette.muted)

            if auth.resendSecondsRemaining > 0 {
                Text(String(format: L10n.Auth.resendCodeIn, auth.resendSecondsRemaining))
                    .font(AuthType.bodyMedium)
                    .foregroundStyle(AuthPalette.muted)
            } else {
                Button {
                    auth.resendCode()
                } label: {
                    Text(L10n.Auth.resendCode)
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(resendEnabled ? AuthPalette.accent : AuthPalette.muted)
                }
                .buttonStyle(.plain)
                .disabled(!resendEnabled)
                .accessibilityLabel(L10n.Auth.resendCode)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var backupSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.Auth.backupHint)
                    .font(AuthType.body)
                    .foregroundStyle(AuthPalette.muted)

                TextField("••••", text: $backupCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(AuthType.otpDigit)
                    .multilineTextAlignment(.center)
                    .authFieldBackground(focused: true)
                    .onChange(of: backupCode) { _, newValue in
                        backupCode = String(newValue.filter(\.isNumber).prefix(4))
                    }

                if let otpError = auth.otpError {
                    AuthInlineError(message: otpError)
                }

                Spacer(minLength: 8)

                AuthBlackButton(
                    title: L10n.Auth.backupSubmit,
                    enabled: backupCode.count == 4,
                    isLoading: auth.otpVerifyPhase == .loading
                ) {
                    auth.submitBackupCode(backupCode)
                }
            }
            .padding(AuthLayout.pageInset)
            .background(AuthPalette.page.ignoresSafeArea())
            .navigationTitle(L10n.Auth.backupTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { showBackup = false }
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(AuthPalette.accent)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: auth.step) { _, step in
            if step != .otp { showBackup = false }
        }
    }

    private func otpBox(index: Int) -> some View {
        let isActive = focusedIndex == index
        return TextField("", text: Binding(
            get: { auth.otpDigits[index] },
            set: { newValue in
                let digits = newValue.filter(\.isNumber)
                if digits.count > 1 {
                    auth.applyOTPPaste(String(digits))
                    return
                }
                auth.setOTPDigit(newValue, at: index)
                if !auth.otpDigits[index].isEmpty, index < 3 {
                    focusedIndex = index + 1
                }
            }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .multilineTextAlignment(.center)
        .font(AuthType.otpDigit)
        .foregroundStyle(AuthPalette.ink)
        .focused($focusedIndex, equals: index)
        .frame(maxWidth: .infinity, minHeight: AuthLayout.otpBoxHeight, maxHeight: AuthLayout.otpBoxHeight)
        .background(
            RoundedRectangle(cornerRadius: AuthLayout.otpBoxRadius, style: .continuous)
                .fill(AuthPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AuthLayout.otpBoxRadius, style: .continuous)
                .strokeBorder(
                    auth.otpError != nil
                        ? VuumColor.danger.opacity(0.7)
                        : (isActive ? AuthPalette.accentBright : Color.clear),
                    lineWidth: 2
                )
        )
        .accessibilityLabel(String(format: L10n.Auth.digitA11y, index + 1))
        .accessibilityHint(L10n.Auth.digitHintA11y)
        .accessibilityValue(auth.otpDigits[index].isEmpty ? L10n.Auth.emptyA11y : auth.otpDigits[index])
    }

    /// Only move focus after the rider has already tapped a digit field — never on appear.
    private func advanceFocusIfNeeded() {
        guard focusedIndex != nil else { return }
        if let empty = auth.otpDigits.firstIndex(where: { $0.isEmpty }) {
            focusedIndex = empty
        } else {
            focusedIndex = 3
        }
    }
}
