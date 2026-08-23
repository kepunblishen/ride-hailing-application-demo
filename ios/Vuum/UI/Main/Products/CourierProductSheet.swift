import SwiftUI

struct CourierProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var packageSize = PackageSize.medium
    @State private var isFragile = false
    @State private var recipientName = ""
    @State private var recipientPhone = ""
    @State private var notes = ""

    private enum PackageSize: String, CaseIterable, Identifiable {
        case small
        case medium
        case large

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .small: return L10n.Products.sizeSmall
            case .medium: return L10n.Products.sizeMedium
            case .large: return L10n.Products.sizeLarge
            }
        }
    }

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.courier(distanceMeters: meters)
    }

    private var composedNotes: String {
        var parts: [String] = ["Size: \(packageSize.localizedTitle)"]
        if isFragile { parts.append(L10n.Products.fragile) }
        let name = recipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { parts.append("Recipient: \(name)") }
        let phone = recipientPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phone.isEmpty { parts.append("Phone: \(phone)") }
        let extra = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { parts.append(extra) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: L10n.Services.courier,
                subtitle: L10n.Products.courierSubtitle,
                symbol: "shippingbox.fill",
                confirmTitle: L10n.Products.continueToBook,
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate,
                canConfirm: !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Section(L10n.Products.packageDetails) {
                    Picker(L10n.Products.packageSize, selection: $packageSize) {
                        ForEach(PackageSize.allCases) { size in
                            Text(size.localizedTitle).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(L10n.Products.fragile, isOn: $isFragile)

                    TextField(L10n.Products.recipientName, text: $recipientName)
                        .textContentType(.name)

                    TextField(L10n.Products.recipientPhone, text: $recipientPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    TextField(L10n.Products.packageNotes, text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    packageNotes: composedNotes,
                    injectTier: estimate
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle(L10n.Services.courier)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onAppear { seedPlaces() }
        }
        .presentationDetents([.medium, .large])
    }

    private func seedPlaces() {
        let market: AppLocale.Market = AppLocale.current == .kenya ? .kenya : .drc
        pickup = tripSession.pickup
        dropoff = MockPlaces.destinations(for: market).first ?? dropoff
    }
}
