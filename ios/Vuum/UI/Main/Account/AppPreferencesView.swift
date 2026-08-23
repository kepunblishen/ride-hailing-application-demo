import SwiftUI

struct AppPreferencesView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var appLocale: AppLocale
    @AppStorage(AppLocale.overrideKey) private var marketOverride = "auto"
    @AppStorage("vuum.distanceUnit") private var distanceUnit = "km"
    @AppStorage("vuum.mapTraffic") private var mapTraffic = true

    private var currencyLabel: String {
        AppLocale.currencySubtitle(for: appLocale.fareMarket)
    }

    var body: some View {
        List {
            Section {
                Picker(selection: $preferences.languageCode) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                } label: {
                    Text(L10n.Account.language)
                }
            } footer: {
                Text(L10n.Account.languageFooter)
            }

            Section {
                Picker(selection: Binding(
                    get: { marketOverride },
                    set: { newValue in
                        marketOverride = newValue
                        appLocale.setOverride(AppLocale.Override(rawValue: newValue) ?? .auto)
                    }
                )) {
                    Text(L10n.Settings.marketAuto).tag("auto")
                    Text(L10n.Settings.marketDRC).tag("drc")
                    Text(L10n.Settings.marketKenya).tag("kenya")
                } label: {
                    Text(L10n.Settings.market)
                }
                LabeledContent(L10n.Settings.activeMarket, value: appLocale.marketDisplayName)
                LabeledContent(L10n.Settings.currency, value: currencyLabel)
            } footer: {
                Text(L10n.Settings.marketFooter)
            }

            Section {
                Toggle(isOn: $preferences.lowDataMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Low-data / lite mode")
                        Text("Simpler map, traffic off, lighter tiles when coverage is weak.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(VuumColor.brand)
            } footer: {
                Text("Use this on slow mobile networks. You can turn traffic back on anytime under Maps.")
            }

            Section(L10n.Settings.maps) {
                Picker(selection: $distanceUnit) {
                    Text(L10n.Settings.kilometers).tag("km")
                    Text(L10n.Settings.miles).tag("mi")
                } label: {
                    Text(L10n.Settings.distance)
                }
                Toggle(L10n.Settings.traffic, isOn: $mapTraffic)
                    .disabled(preferences.lowDataMode)
            }
        }
        .navigationTitle(L10n.Account.preferencesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appLocale.setOverride(AppLocale.Override(rawValue: marketOverride) ?? .auto)
        }
        .onChange(of: preferences.lowDataMode) { _, enabled in
            if enabled { mapTraffic = false }
        }
    }
}
