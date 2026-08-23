import SwiftUI

struct TermsAgreeView: View {
    @ObservedObject var auth: AuthFlowController
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(AuthPalette.link)
                .padding(.top, AuthLayout.titleTop)
                .accessibilityHidden(true)

            Text(L10n.Auth.termsTitle)
                .font(AuthType.title)
                .foregroundStyle(AuthPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)

            Text(L10n.Auth.termsBodyLead)
                .font(AuthType.body)
                .foregroundStyle(AuthPalette.ink)
                .padding(.top, 16)

            HStack(spacing: 0) {
                Button(L10n.Auth.termsOfUse) { showTerms = true }
                Text(L10n.Auth.termsBodyMid)
                Button(L10n.Auth.privacyNotice) { showPrivacy = true }
            }
            .font(AuthType.body)
            .buttonStyle(.plain)
            .foregroundStyle(AuthPalette.link)
            .padding(.top, 4)

            Text(L10n.Auth.termsBodyAge)
                .font(AuthType.body)
                .foregroundStyle(AuthPalette.ink)
                .padding(.top, 4)

            Spacer(minLength: 16)

            Rectangle()
                .fill(AuthPalette.hairline)
                .frame(height: 1)
                .padding(.bottom, 18)

            Button {
                auth.agreedToTerms.toggle()
            } label: {
                HStack {
                    Text(L10n.Auth.iAgree)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuthPalette.ink)
                    Spacer()
                    Image(systemName: auth.agreedToTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 28))
                        .foregroundStyle(auth.agreedToTerms ? AuthPalette.accent : AuthPalette.ink)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 22)
            .accessibilityLabel(L10n.Auth.iAgree)
            .accessibilityHint(L10n.Auth.termsAgreeHintA11y)
            .accessibilityAddTraits(auth.agreedToTerms ? [.isSelected] : [])

            HStack {
                AuthCircleBackButton { auth.goBack() }
                Spacer()
                AuthNextPill(enabled: auth.agreedToTerms) {
                    auth.goToConfirmInfo()
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, AuthLayout.pageInset)
        .background(AuthPalette.page.ignoresSafeArea())
        .sheet(isPresented: $showTerms) {
            AuthLegalDocumentSheet(
                title: L10n.Auth.termsOfUse,
                bodyText: L10n.Auth.termsDocument,
                isPresented: $showTerms
            )
        }
        .sheet(isPresented: $showPrivacy) {
            AuthLegalDocumentSheet(
                title: L10n.Auth.privacyNotice,
                bodyText: L10n.Auth.privacyDocument,
                isPresented: $showPrivacy
            )
        }
    }
}
