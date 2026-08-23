import SwiftUI

struct AboutLegalView: View {
    @ObservedObject private var diagnostics = DeveloperDiagnostics.shared
    @ObservedObject private var mapsDiagnostics = GoogleMapsDiagnostics.shared
    @State private var unlockedToast = false

    var body: some View {
        List {
            Section {
                LabeledContent(L10n.Legal.app, value: VuumTheme.displayName)
                Button {
                    if diagnostics.registerUnlockTap() {
                        unlockedToast = true
                    }
                } label: {
                    LabeledContent(
                        L10n.Settings.version,
                        value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                    )
                }
                .buttonStyle(.plain)
                LabeledContent(
                    L10n.Settings.build,
                    value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                )
            }

            if diagnostics.isUnlocked {
                Section("Maps (QA)") {
                    LabeledContent("API key present", value: mapsDiagnostics.keyPresenceLabel)
                    LabeledContent("Maps SDK", value: mapsDiagnostics.mapsSDKConfiguredLabel)
                    LabeledContent("Surface", value: mapsDiagnostics.liveMapSurfaceLabel)
                    LabeledContent(
                        "Last error",
                        value: mapsDiagnostics.lastErrorCode ?? "None"
                    )
                    Text(mapsDiagnostics.blankTilesHypothesis)
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                    NavigationLink {
                        DiagnosticsToolsView()
                    } label: {
                        Label(L10n.Legal.diagnostics, systemImage: "wrench.and.screwdriver")
                    }
                }
            }

            Section(L10n.Settings.legal) {
                NavigationLink(L10n.Settings.terms) {
                    LegalDocumentView(
                        title: L10n.Settings.terms,
                        bodyText: """
                        By using Vuum you agree to the operator’s terms for booking rides, payments in CDF and USD, cancellations, and conduct toward drivers and riders.

                        Corporate and field-sales programs may include additional agreements managed by Congo Mobility SARL.
                        """
                    )
                }
                NavigationLink(L10n.Settings.privacyPolicy) {
                    LegalDocumentView(
                        title: L10n.Settings.privacyPolicy,
                        bodyText: """
                        Vuum processes account details, trip locations, and payment preferences to provide rides and safety features.

                        You can manage sharing preferences under Privacy in Settings.
                        """
                    )
                }
                NavigationLink(L10n.Settings.community) {
                    LegalDocumentView(
                        title: L10n.Settings.community,
                        bodyText: """
                        Treat drivers and riders with respect. No harassment, fraud, or unsafe behavior. Violations may lead to account suspension.
                        """
                    )
                }
                NavigationLink(L10n.Settings.licenses) {
                    LegalDocumentView(
                        title: L10n.Settings.licenses,
                        bodyText: """
                        Vuum includes open-source software:

                        • ComponentsKit — MIT License
                        • Google Maps SDK for iOS — Google Maps Platform Terms
                        • KeychainSwift — MIT License

                        Full license texts are available from each project’s repository.
                        """
                    )
                }
            }

            Section(L10n.Settings.operatorLabel) {
                LabeledContent(L10n.Settings.operatorLabel, value: "Congo Mobility SARL")
                LabeledContent(L10n.Settings.marketsLabel, value: "DRC · Kenya")
            }
        }
        .navigationTitle(L10n.Account.about)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Legal.diagnosticsUnlocked, isPresented: $unlockedToast) {
            Button(L10n.Common.gotIt, role: .cancel) {}
        } message: {
            Text(L10n.Legal.diagnosticsUnlockedMsg)
        }
    }
}

struct LegalDocumentView: View {
    let title: String
    let bodyText: String

    var body: some View {
        ScrollView {
            Text(bodyText)
                .font(.body)
                .foregroundStyle(VuumColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(VuumColor.pageBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
