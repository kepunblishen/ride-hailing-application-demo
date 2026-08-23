import SwiftUI

/// Corporate WhatsApp + QR / code onboarding (RFQ O03 / O04).
struct CorporateOnboardingView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.openURL) private var openURL

    @State private var corporateCode = ""
    @State private var qrPayload = ""
    @State private var statusMessage: String?
    @AppStorage("vuum.corporate.joinedCode") private var joinedCode = ""

    private let whatsAppNumber = "243970000200"
    private let sampleQRPayload = "VUUM-CORP:MININGCO-LUB"

    var body: some View {
        List {
            if !joinedCode.isEmpty {
                Section("Linked organisation") {
                    LabeledContent("Corporate code", value: joinedCode)
                    Text("Your account is linked for company-wallet trips and spend limits.")
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }

            Section {
                Button {
                    openWhatsAppInvite()
                } label: {
                    Label("Continue on WhatsApp", systemImage: "message.fill")
                }
            } header: {
                Text("WhatsApp")
            } footer: {
                Text("Opens a pre-filled WhatsApp message with your corporate join request.")
            }

            Section {
                TextField("Corporate code", text: $corporateCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Join with code") {
                    applyCode(corporateCode)
                }
                .disabled(corporateCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 4)
            } header: {
                Text("Code registration")
            }

            Section {
                TextField("Paste QR payload", text: $qrPayload)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Apply QR payload") {
                    applyQR(qrPayload)
                }
                .disabled(qrPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Use sample invite QR") {
                    qrPayload = sampleQRPayload
                    applyQR(sampleQRPayload)
                }
            } header: {
                Text("QR onboarding")
            } footer: {
                Text("Scan a printed invite with the system Camera app, then paste the VUUM-CORP payload here. Live camera scanning can plug into the same parser.")
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle("Join company")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openWhatsAppInvite() {
        let name = session.displayName.isEmpty ? "rider" : session.displayName
        let text = "Hi Vuum Corporate — please onboard \(name) with code \(corporateCode.isEmpty ? "PENDING" : corporateCode.uppercased())."
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        if let appURL = URL(string: "whatsapp://send?phone=\(whatsAppNumber)&text=\(encoded)") {
            openURL(appURL)
        } else if let web = URL(string: "https://wa.me/\(whatsAppNumber)?text=\(encoded)") {
            openURL(web)
        }
    }

    private func applyCode(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count >= 4 else {
            statusMessage = "Enter a valid corporate code."
            return
        }
        joinedCode = code
        statusMessage = "Joined with corporate code \(code)."
    }

    private func applyQR(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("VUUM-CORP:") {
            let code = String(trimmed.dropFirst("VUUM-CORP:".count))
            applyCode(code)
        } else {
            applyCode(trimmed)
        }
    }
}
