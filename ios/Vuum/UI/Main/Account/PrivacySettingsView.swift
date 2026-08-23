import SwiftUI
import UIKit

struct PrivacySettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.openURL) private var openURL
    @AppStorage(PermissionCenter.preciseLocationDefaultsKey) private var preciseLocation = true
    @AppStorage("vuum.privacy.shareAnalytics") private var analytics = true
    @AppStorage("vuum.privacy.personalizedOffers") private var personalizedOffers = false
    @AppStorage("vuum.privacy.showActivityStatus") private var activityStatus = true

    private var locationStatusLabel: String {
        if !location.locationServicesEnabled { return L10n.Settings.off }
        switch permissions.locationAuthorization {
        case .authorizedAlways, .authorizedWhenInUse: return L10n.Settings.on
        case .denied, .restricted: return L10n.Settings.off
        case .notDetermined: return L10n.Settings.off
        @unknown default: return L10n.Settings.off
        }
    }

    private var notificationStatusLabel: String {
        switch permissions.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return L10n.Settings.on
        default: return L10n.Settings.off
        }
    }

    var body: some View {
        List {
            Section(L10n.Settings.permissions) {
                LabeledContent(L10n.Settings.locationPermission, value: locationStatusLabel)
                LabeledContent(L10n.Settings.notificationPermission, value: notificationStatusLabel)
                LabeledContent(
                    L10n.Settings.micPermission,
                    value: permissions.microphoneAuthorized ? L10n.Settings.on : L10n.Settings.off
                )
                if permissions.isLocationDenied || !location.locationServicesEnabled {
                    Text(L10n.Settings.preciseLocationNote)
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                    Button(L10n.Settings.openSystemSettings) {
                        if let url = permissions.systemSettingsURL {
                            openURL(url)
                        }
                    }
                } else if permissions.isLocationNotDetermined {
                    Button(L10n.Settings.enableLocation) {
                        location.requestWhenInUse()
                    }
                } else {
                    Button(L10n.Settings.openSystemSettings) {
                        if let url = permissions.systemSettingsURL {
                            openURL(url)
                        }
                    }
                }
            }

            Section(L10n.Settings.locationSection) {
                Toggle(L10n.Settings.preciseLocation, isOn: $preciseLocation)
                    .onChange(of: preciseLocation) { _, _ in
                        permissions.applyPreciseLocationPreference()
                    }
                    .disabled(!permissions.isLocationAuthorized)
                Text(L10n.Settings.preciseLocationNote)
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }

            Section(L10n.Settings.dataSection) {
                Toggle(L10n.Settings.analytics, isOn: $analytics)
                Toggle(L10n.Settings.personalizedOffers, isOn: $personalizedOffers)
                Toggle(L10n.Settings.activityStatus, isOn: $activityStatus)
            }

            Section(L10n.Settings.controls) {
                NavigationLink(L10n.Settings.downloadData) {
                    PrivacyActionView(
                        title: L10n.Settings.downloadData,
                        message: L10n.Settings.downloadDataMsg
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
                NavigationLink(L10n.Settings.deleteAccount) {
                    DeleteAccountView()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(L10n.Account.privacy)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await permissions.refreshStatuses()
        }
    }
}

private struct PrivacyActionView: View {
    let title: String
    let message: String
    @State private var submitted = false

    var body: some View {
        List {
            Section {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Section {
                Button(submitted ? L10n.Settings.requestSent : L10n.Settings.submitRequest) {
                    submitted = true
                }
                .disabled(submitted)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DeleteAccountView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var tripSession: TripSession
    @State private var confirmText = ""
    @State private var showConfirm = false

    private var canDelete: Bool {
        confirmText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        List {
            Section {
                Text(L10n.Settings.deleteAccountBody)
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Section {
                TextField(L10n.Settings.deleteConfirmHint, text: $confirmText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            Section {
                Button(L10n.Settings.deleteAccount, role: .destructive) {
                    showConfirm = true
                }
                .disabled(!canDelete)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(L10n.Settings.deleteAccount)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Settings.deleteConfirmTitle, isPresented: $showConfirm) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.delete, role: .destructive) {
                tripSession.resetToHome()
                session.deleteAccount()
            }
        } message: {
            Text(L10n.Settings.deleteConfirmMsg)
        }
    }
}
