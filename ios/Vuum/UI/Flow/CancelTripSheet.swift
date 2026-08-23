import SwiftUI

/// Cancellation reasons with free-window vs fee messaging.
struct CancelTripSheet: View {
    let title: String
    var isFree: Bool = true
    var feeLocal: Int = 0
    var market: AppLocale.Market = .drc
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let reasons = [
        "Waited too long",
        "Driver asked to cancel",
        "Wrong pickup location",
        "Changed my plans",
        "Other",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isFree || feeLocal <= 0 {
                        Label("Free cancellation", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("You won’t be charged for cancelling now.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Cancellation fee may apply", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Text("A fee of \(AppLocale.formatPrimary(local: feeLocal, market: market)) may be charged for this cancellation.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Why are you cancelling?") {
                    ForEach(reasons, id: \.self) { reason in
                        Button(reason) {
                            onConfirm(reason)
                            dismiss()
                        }
                        .foregroundStyle(VuumColor.primaryText)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep trip") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
