import SwiftUI
import UIKit

// MARK: - Palette & type

enum AuthPalette {
    static let page = Color(.systemBackground)
    static let fieldFill = Color(.tertiarySystemFill)
    static let fieldFillPressed = Color(.secondarySystemFill)
    static let ink = Color(.label)
    static let muted = Color(.secondaryLabel)
    static let hairline = Color(.separator)
    static let accent = VuumColor.accent
    static let accentBright = VuumColor.accentBright
    static let link = VuumColor.accent
    static let onAccent = VuumColor.accentOn
}

enum AuthType {
    /// Onboarding headlines — SF Pro, ~26pt semibold (not display/heavy).
    static let hero = Font.system(size: 28, weight: .semibold)
    static let title = Font.system(size: 26, weight: .semibold)
    static let titleCompact = Font.system(size: 24, weight: .semibold)
    static let body = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    static let bodySemibold = Font.system(size: 16, weight: .semibold)
    static let label = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let fine = Font.system(size: 12, weight: .regular)
    static let button = Font.system(size: 17, weight: .semibold)
    static let buttonSecondary = Font.system(size: 16, weight: .semibold)
    static let otpDigit = Font.system(size: 32, weight: .bold)
}

enum AuthLayout {
    static let pageInset: CGFloat = 24
    static let fieldHeight: CGFloat = 54
    static let fieldRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 28
    static let otpBoxWidth: CGFloat = 72
    static let otpBoxHeight: CGFloat = 88
    static let otpBoxRadius: CGFloat = 14
    /// Even gaps between OTP boxes across the full content width.
    static let otpBoxSpacing: CGFloat = 12
    static let topBarHeight: CGFloat = 56
    static let controlSpacing: CGFloat = 12
    static let sectionGap: CGFloat = 28
    static let titleTop: CGFloat = 8
}

// MARK: - Country catalog

struct AuthCountry: Identifiable, Hashable {
    var id: String { dialCode + iso }
    let iso: String
    let name: String
    let dialCode: String
    let flag: String

    /// Base catalog (KE / CD featured). Prefer `catalogForPresentation` for UI lists.
    static let catalog: [AuthCountry] = [
        AuthCountry(iso: "KE", name: "Kenya", dialCode: "+254", flag: "🇰🇪"),
        AuthCountry(iso: "CD", name: "DR Congo", dialCode: "+243", flag: "🇨🇩"),
        AuthCountry(iso: "UG", name: "Uganda", dialCode: "+256", flag: "🇺🇬"),
        AuthCountry(iso: "TZ", name: "Tanzania", dialCode: "+255", flag: "🇹🇿"),
        AuthCountry(iso: "RW", name: "Rwanda", dialCode: "+250", flag: "🇷🇼"),
        AuthCountry(iso: "BI", name: "Burundi", dialCode: "+257", flag: "🇧🇮"),
        AuthCountry(iso: "SS", name: "South Sudan", dialCode: "+211", flag: "🇸🇸"),
        AuthCountry(iso: "ET", name: "Ethiopia", dialCode: "+251", flag: "🇪🇹"),
        AuthCountry(iso: "NG", name: "Nigeria", dialCode: "+234", flag: "🇳🇬"),
        AuthCountry(iso: "GH", name: "Ghana", dialCode: "+233", flag: "🇬🇭"),
        AuthCountry(iso: "ZA", name: "South Africa", dialCode: "+27", flag: "🇿🇦"),
        AuthCountry(iso: "AE", name: "United Arab Emirates", dialCode: "+971", flag: "🇦🇪"),
        AuthCountry(iso: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧"),
        AuthCountry(iso: "US", name: "United States", dialCode: "+1", flag: "🇺🇸"),
        AuthCountry(iso: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦"),
        AuthCountry(iso: "FR", name: "France", dialCode: "+33", flag: "🇫🇷"),
        AuthCountry(iso: "BE", name: "Belgium", dialCode: "+32", flag: "🇧🇪"),
        AuthCountry(iso: "IN", name: "India", dialCode: "+91", flag: "🇮🇳"),
        AuthCountry(iso: "CN", name: "China", dialCode: "+86", flag: "🇨🇳"),
    ]

    /// Catalog with the `AppLocale` default market (+254 KE or +243 CD) listed first.
    static var catalogForPresentation: [AuthCountry] {
        let preferred = AppLocale.defaultCountryCode
        var list = catalog
        if let idx = list.firstIndex(where: { $0.dialCode == preferred }), idx != 0 {
            let item = list.remove(at: idx)
            list.insert(item, at: 0)
        }
        return list
    }

    static func match(dialCode: String, flag: String) -> AuthCountry? {
        catalog.first { $0.dialCode == dialCode && $0.flag == flag }
            ?? catalog.first { $0.dialCode == dialCode }
    }
}

// MARK: - Buttons

struct AuthBlackButton: View {
    let title: String
    var enabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    private var interactive: Bool { enabled && !isLoading }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AuthPalette.onAccent)
                } else {
                    Text(title)
                        .font(AuthType.button)
                        .foregroundStyle(interactive ? AuthPalette.onAccent : AuthPalette.onAccent.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: AuthLayout.fieldHeight)
            .background(
                interactive || isLoading
                    ? AuthPalette.accent
                    : AuthPalette.accent.opacity(0.35),
                in: Capsule()
            )
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!interactive)
        .accessibilityLabel(isLoading ? L10n.Auth.sendingCode : title)
        .accessibilityHint(interactive ? L10n.Auth.continueHintA11y : L10n.Auth.continueDisabledHintA11y)
    }
}

struct AuthGrayButton: View {
    let title: String
    /// Asset catalog name — e.g. AuthIconApple / AuthIconGoogle / AuthIconEmail
    var assetIcon: String? = nil
    /// SF Symbol used when the catalog image is missing or empty.
    var systemIcon: String? = nil
    var iconSize: CGFloat = 20
    var enabled: Bool = true
    let action: () -> Void

    private var resolvedCatalogImage: UIImage? {
        guard let assetIcon, let image = UIImage(named: assetIcon) else { return nil }
        // Reject zero-size / empty placeholders so SF Symbol fallbacks can show.
        guard image.size.width > 1, image.size.height > 1 else { return nil }
        return image
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let resolvedCatalogImage {
                    Image(uiImage: resolvedCatalogImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: iconSize * 0.92, weight: .medium))
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AuthType.buttonSecondary)
            }
            .foregroundStyle(enabled ? AuthPalette.ink : AuthPalette.muted)
            .frame(maxWidth: .infinity)
            .frame(height: AuthLayout.fieldHeight)
            .background(
                AuthPalette.fieldFill,
                in: Capsule()
            )
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

struct AuthCircleBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AuthPalette.ink)
                .frame(width: 44, height: 44)
                .background(AuthPalette.fieldFill, in: Circle())
        }
        .buttonStyle(AuthPressStyle())
        .accessibilityLabel(L10n.Common.back)
    }
}

struct AuthNextPill: View {
    var enabled: Bool
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(AuthPalette.onAccent)
                } else {
                    Text(L10n.Common.next)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .font(AuthType.bodySemibold)
            .foregroundStyle(enabled ? AuthPalette.onAccent : AuthPalette.onAccent.opacity(0.55))
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(
                enabled ? AuthPalette.accent : AuthPalette.accent.opacity(0.32),
                in: Capsule()
            )
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!enabled || isLoading)
        .accessibilityLabel(L10n.Common.next)
    }
}

struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(AuthPalette.hairline).frame(height: 1)
            Text(L10n.Common.or)
                .font(AuthType.caption)
                .foregroundStyle(AuthPalette.muted)
            Rectangle().fill(AuthPalette.hairline).frame(height: 1)
        }
    }
}

struct AuthInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.danger)
            Text(message)
                .font(AuthType.caption)
                .foregroundStyle(VuumColor.danger)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .accessibilityLabel(message)
    }
}

struct AuthLegalDocumentSheet: View {
    let title: String
    let bodyText: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(bodyText)
                    .font(AuthType.body)
                    .foregroundStyle(AuthPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AuthLayout.pageInset)
            }
            .background(AuthPalette.page.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.close) { isPresented = false }
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(AuthPalette.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct AuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Fields

struct AuthFieldBackground: ViewModifier {
    var focused: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: AuthLayout.fieldHeight)
            .background(
                AuthPalette.fieldFill,
                in: RoundedRectangle(cornerRadius: AuthLayout.fieldRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AuthLayout.fieldRadius, style: .continuous)
                    .strokeBorder(focused ? AuthPalette.accent : Color.clear, lineWidth: 2)
            )
    }
}

extension View {
    func authFieldBackground(focused: Bool = false) -> some View {
        modifier(AuthFieldBackground(focused: focused))
    }
}

struct AuthCountryCodeButton: View {
    let flag: String
    let dialCode: String
    var showsDialCode: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(flag)
                    .font(.system(size: 22))
                if showsDialCode {
                    Text(dialCode)
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(AuthPalette.ink)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AuthPalette.muted)
            }
            .padding(.horizontal, showsDialCode ? 12 : 14)
            .frame(height: AuthLayout.fieldHeight)
            .background(
                AuthPalette.fieldFill,
                in: RoundedRectangle(cornerRadius: AuthLayout.fieldRadius, style: .continuous)
            )
        }
        .buttonStyle(AuthPressStyle())
        .accessibilityLabel(String(format: L10n.Auth.countryCodeA11y, dialCode))
        .accessibilityHint(L10n.Auth.countryPickerHintA11y)
    }
}

// MARK: - Country picker sheet

struct AuthCountryPickerSheet: View {
    @Binding var isPresented: Bool
    let selectedDialCode: String
    let selectedFlag: String
    let onSelect: (AuthCountry) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [AuthCountry] {
        let base = AuthCountry.catalogForPresentation
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(q)
                || $0.dialCode.contains(q)
                || $0.iso.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, AuthLayout.pageInset)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                Divider().overlay(AuthPalette.hairline)

                if filtered.isEmpty {
                    Text(L10n.Auth.noCountries)
                        .font(AuthType.body)
                        .foregroundStyle(AuthPalette.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { country in
                            countryRow(country)
                                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                                .listRowSeparatorTint(AuthPalette.hairline)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(AuthPalette.page.ignoresSafeArea())
            .navigationTitle(L10n.Auth.countryCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { isPresented = false }
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(AuthPalette.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { searchFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AuthPalette.muted)
            TextField(L10n.Auth.searchCountry, text: $query)
                .font(AuthType.body)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AuthPalette.muted.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Auth.clearSearch)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            AuthPalette.fieldFill,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func countryRow(_ country: AuthCountry) -> some View {
        let selected = country.dialCode == selectedDialCode && country.flag == selectedFlag
        return Button {
            onSelect(country)
            isPresented = false
        } label: {
            HStack(spacing: 14) {
                Text(country.flag)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(AuthType.bodyMedium)
                        .foregroundStyle(AuthPalette.ink)
                    Text(country.iso)
                        .font(AuthType.fine)
                        .foregroundStyle(AuthPalette.muted)
                }
                Spacer(minLength: 8)
                Text(country.dialCode)
                    .font(AuthType.bodySemibold)
                    .foregroundStyle(AuthPalette.ink)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AuthPalette.accent)
                        .padding(.leading, 4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Auth language picker

/// Compact language control for Get Started / onboarding footers.
struct AuthLanguagePicker: View {
    @ObservedObject var locale: AuthLocale

    var body: some View {
        Menu {
            ForEach(AuthLocale.Language.allCases) { lang in
                Button {
                    locale.select(lang)
                } label: {
                    HStack {
                        Text("\(lang.flagEmoji)  \(lang.displayName)")
                        if locale.language == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityHidden(true)
                Text("\(locale.language.flagEmoji) \(locale.language.displayName)")
                    .font(AuthType.bodyMedium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AuthPalette.accent)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Auth.language)
        .accessibilityValue(locale.language.displayName)
    }
}

// MARK: - Keyboard

extension View {
    /// Resign first responder when tapping non-editable chrome so the keyboard collapses.
    func dismissKeyboardOnOutsideTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
