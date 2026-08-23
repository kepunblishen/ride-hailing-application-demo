import SwiftUI

struct WalletSettingsView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var payments: PaymentMethodStore
    @EnvironmentObject private var session: SessionStore

    @State private var showAddFunds = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    var body: some View {
        List {
            Section("Balances") {
                switch market {
                case .kenya:
                    LabeledContent("KSh wallet", value: "KSh \(payments.walletBalanceKSh.formatted())")
                case .drc, .both:
                    LabeledContent("CDF wallet", value: "CDF \(payments.walletBalanceCDF.formatted())")
                    LabeledContent("USD wallet", value: String(format: "$%.2f", payments.walletBalanceUSD))
                    if market == .both {
                        LabeledContent("KSh wallet", value: "KSh \(payments.walletBalanceKSh.formatted())")
                    }
                }
            }

            Section("Quick actions") {
                Button { showAddFunds = true } label: {
                    Label("Add funds", systemImage: "plus.circle.fill")
                }
                NavigationLink("Manage payment methods") {
                    PaymentMethodsView()
                }
                NavigationLink("Payment history") {
                    PaymentHistoryView()
                }
                NavigationLink("Vouchers, cards & receipts") {
                    PaymentHubView(showsDoneButton: false)
                }
            }

            Section {
                Picker("Pay with", selection: Binding(
                    get: { payments.selectedMethod },
                    set: { method in
                        payments.select(method)
                        if !tripSession.bookOnCompanyWallet {
                            tripSession.paymentMethod = method
                        }
                    }
                )) {
                    ForEach(payments.availableMethods(for: market)) { method in
                        Text(method.title).tag(method)
                    }
                }
            } header: {
                Text("Default for trips")
            } footer: {
                Text("Your default method is applied when a trip ends. You can still change it on the ride options screen.")
            }

            if !payments.transactions.isEmpty {
                Section("Recent") {
                    ForEach(Array(payments.transactions.prefix(5))) { tx in
                        NavigationLink {
                            PaymentTransactionDetailView(transaction: tx)
                        } label: {
                            PaymentTransactionRow(transaction: tx)
                        }
                    }
                }
            }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            payments.ensureValidSelection(for: market)
            if !tripSession.bookOnCompanyWallet {
                tripSession.paymentMethod = payments.selectedMethod
            }
        }
        .sheet(isPresented: $showAddFunds) {
            AddFundsShellView(market: market)
                .environmentObject(payments)
        }
    }
}

#Preview {
    NavigationStack {
        WalletSettingsView()
    }
    .environmentObject(TripSession())
    .environmentObject(PaymentMethodStore())
    .environmentObject(SessionStore())
}

/// Sheet-friendly wallet surface used from other flows.
struct WalletView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WalletSettingsView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
