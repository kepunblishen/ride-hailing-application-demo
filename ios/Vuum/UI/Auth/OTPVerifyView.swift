import SwiftUI

struct OTPVerifyView: View {
    @ObservedObject var auth: AuthFlowController
    @FocusState private var focusedIndex: Int?
    @State private var showBackup = false
    @State private var backupCode = ""

    private var resendTitle: String {
        if auth.resendSecondsRemaining > 0 {
            return String(format: L10n.Auth.resendIn, auth.resendSecondsRemaining)
        }
        return L10n.Auth.resendSMS
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: L10n.Auth.otpPrompt, auth.maskedPhoneForOTP))
                .font(AuthType.titleCompact)
                .foregroundStyle(AuthPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AuthLayout.titleTop)

            Button {
                auth.goBack()
            } label: {
                Text(L10n.Auth.changedNumber)
                    .font(AuthType.bodyMedium)
                    .underline(true, color: AuthPalette.ink.opacity(0.85))
                    .foregroundStyle(AuthPalette.ink)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .accessibilityLabel(L10n.Auth.changedNumber)
            .accessibilityHint("Goes back to edit your phone number")

            HStack(spacing: AuthLayout.controlSpacing) {
                ForEach(0..<4, id: \.self) { index in
                    otpBox(index: index)
                }
            }
            .padding(.top, 32)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Verification code")

            if let otpError = auth.otpError {
                AuthInlineError(message: otpError)
            }

            VStack(spacing: AuthLayout.controlSpacing) {
                AuthGrayButton(title: resendTitle, enabled: auth.canResendOTP) {
                    auth.resendCode()
                }
                AuthGrayButton(title: L10n.Auth.backupCode) {
                    backupCode = ""
                    showBackup = true
                }
            }
            .padding(.top, 28)

            Spacer(minLength: 16)

            HStack {
                AuthCircleBackButton { auth.goBack() }
                Spacer()
                AuthNextPill(
                    enabled: auth.canSubmitOTP,
                    isLoading: auth.otpVerifyPhase == .loading
                ) {
                    auth.goToTerms()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, AuthLayout.pageInset)
        .background(AuthPalette.page.ignoresSafeArea())
        .onAppear { focusedIndex = 0 }
        .onChange(of: auth.otpDigits) { _, _ in
            advanceFocus()
        }
        .sheet(isPresented: $showBackup) {
            backupSheet
        }
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
                        .foregroundStyle(AuthPalette.ink)
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
        .focused($focusedIndex, equals: index)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AuthPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    auth.otpError != nil
                        ? Color.red.opacity(0.55)
                        : (isActive ? Color.black : Color.clear),
                    lineWidth: 2
                )
        )
        .accessibilityLabel(String(format: L10n.Auth.digitA11y, index + 1))
        .accessibilityHint("Enter the verification code digit")
        .accessibilityValue(auth.otpDigits[index].isEmpty ? "Empty" : auth.otpDigits[index])
    }

    private func advanceFocus() {
        if let empty = auth.otpDigits.firstIndex(where: { $0.isEmpty }) {
            focusedIndex = empty
        } else {
            focusedIndex = 3
        }
    }
}
