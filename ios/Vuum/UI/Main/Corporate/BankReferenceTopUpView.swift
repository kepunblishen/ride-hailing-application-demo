import SwiftUI

/// Corporate wallet top-up via bank payment reference (RFQ Module 2 / P03).
struct BankReferenceTopUpView: View {
    @Binding var balanceCDF: Int

    @State private var amountText = ""
    @State private var payerName = ""
    @State private var bankReference = ""
    @State private var statusMessage: String?
    @State private var pendingRefs: [PendingBankTopUp] = []

    private struct PendingBankTopUp: Identifiable {
        let id: String
        let amountCDF: Int
        let reference: String
        let createdAt: Date
        var credited: Bool
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Company wallet", value: "CDF \(balanceCDF.formatted())")
            }

            Section("Bank transfer details") {
                LabeledContent("Beneficiary", value: "VUUM Ride SARL")
                LabeledContent("Bank", value: "Rawbank · Lubumbashi")
                LabeledContent("Account", value: "00012 3456789 01")
                Text("Include your employee ID in the transfer memo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Record a transfer") {
                TextField("Amount (CDF)", text: $amountText)
                    .keyboardType(.numberPad)
                TextField("Payer name", text: $payerName)
                    .textContentType(.name)
                TextField("Bank reference", text: $bankReference)
                    .textInputAutocapitalization(.characters)
                Button("Submit reference") {
                    submit()
                }
                .disabled(!canSubmit)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !pendingRefs.isEmpty {
                Section("Recent references") {
                    ForEach(pendingRefs) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.reference)
                                .font(.system(.body, design: .monospaced))
                            Text("CDF \(item.amountCDF.formatted()) · \(item.credited ? "Credited" : "Pending match")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bank top-up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canSubmit: Bool {
        let amount = Int(amountText.filter(\.isNumber)) ?? 0
        return amount >= 10_000
            && !payerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bankReference.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
    }

    private func submit() {
        let amount = Int(amountText.filter(\.isNumber)) ?? 0
        let reference = bankReference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard amount >= 10_000, !reference.isEmpty else {
            statusMessage = "Enter at least CDF 10,000 and a bank reference."
            return
        }
        // Local match: credit immediately for presentation; live ops would await bank webhook.
        balanceCDF += amount
        pendingRefs.insert(
            PendingBankTopUp(
                id: UUID().uuidString,
                amountCDF: amount,
                reference: reference,
                createdAt: Date(),
                credited: true
            ),
            at: 0
        )
        statusMessage = "Reference \(reference) matched · CDF \(amount.formatted()) credited."
        amountText = ""
        bankReference = ""
    }
}
