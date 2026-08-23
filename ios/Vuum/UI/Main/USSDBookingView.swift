import SwiftUI

/// USSD booking fallback (RFQ R21) — dial short codes when data is limited.
struct USSDBookingView: View {
    @Environment(\.openURL) private var openURL

    private let codes: [(title: String, code: String, detail: String)] = [
        ("Book a ride", "*123*1#", "Start an on-demand trip by USSD"),
        ("Check fare", "*123*2#", "Estimate fare without mobile data"),
        ("Trip status", "*123*3#", "Follow an active trip by SMS replies"),
        ("Cancel trip", "*123*9#", "Cancel the latest open request"),
    ]

    var body: some View {
        List {
            Section {
                Text("When mobile data is slow or unavailable, dial a Vuum short code. Your carrier may charge standard USSD rates.")
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }

            Section("Short codes") {
                ForEach(codes, id: \.code) { row in
                    Button {
                        dial(row.code)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(VuumColor.brand)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                                Text(row.code)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(VuumColor.brand)
                                Text(row.detail)
                                    .font(.caption)
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle("USSD booking")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dial(_ code: String) {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        guard let url = URL(string: "tel:\(encoded)") else { return }
        openURL(url)
    }
}
