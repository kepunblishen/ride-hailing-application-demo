import SwiftUI

/// Editable rider profile backed by `SessionStore`.
struct PersonalInfoView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var countryCode = "+243"
    @State private var mobile = ""
    @State private var email = ""
    @State private var didSave = false

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && mobile.filter(\.isNumber).count >= 8
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.Settings.accountStatus, value: L10n.Settings.statusActive)
            }

            Section(L10n.Settings.profileName) {
                TextField(L10n.Settings.firstName, text: $firstName)
                    .textContentType(.givenName)
                TextField(L10n.Settings.lastName, text: $lastName)
                    .textContentType(.familyName)
            }

            Section(L10n.Settings.profileContact) {
                HStack {
                    TextField(L10n.Settings.countryCode, text: $countryCode)
                        .keyboardType(.phonePad)
                        .frame(width: 72)
                    TextField(L10n.Settings.mobile, text: $mobile)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                TextField(L10n.Settings.email, text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Picker(selection: $preferences.languageCode) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                } label: {
                    Text(L10n.Settings.preferredLanguage)
                }
            } footer: {
                Text(L10n.Account.languageFooter)
            }

            Section {
                NavigationLink {
                    SecuritySettingsView()
                } label: {
                    Label(L10n.Settings.security, systemImage: "lock.shield.fill")
                }
            }

            Section {
                Button(L10n.Settings.saveChanges) {
                    session.updateProfile(
                        firstName: firstName,
                        lastName: lastName,
                        countryCode: countryCode,
                        mobileNumber: mobile,
                        email: email
                    )
                    didSave = true
                }
                .disabled(!canSave)
            } footer: {
                Text(L10n.Settings.profileFooter)
            }
        }
        .navigationTitle(L10n.Account.personalInfo)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            firstName = session.firstName
            lastName = session.lastName
            countryCode = session.countryCode
            mobile = session.mobileNumber
            email = session.email
        }
        .alert(L10n.Settings.profileUpdated, isPresented: $didSave) {
            Button(L10n.Common.gotIt) { dismiss() }
        } message: {
            Text(L10n.Settings.profileUpdatedMsg)
        }
    }
}
