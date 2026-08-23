import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var payments: PaymentMethodStore
    @EnvironmentObject private var session: SessionStore

    @State private var linkingMethod: PaymentMethod?
    @State private var showAddCard = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var methods: [PaymentMethod] {
        payments.availableMethods(for: market)
    }

    var body: some View {
        List {
            Section {
                ForEach(methods) { method in
                    Button {
                        selectOrSetup(method)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: method.systemImage)
                                .foregroundStyle(VuumColor.brand)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(method.title)
                                        .font(VuumType.rowTitle)
                                        .foregroundStyle(VuumColor.primaryText)
                                    if payments.selectedMethod == method {
                                        Text("Default")
                                            .font(VuumType.micro)
                                            .foregroundStyle(VuumColor.accent)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(VuumColor.accent.opacity(0.16), in: Capsule())
                                    }
                                }
                                Text(payments.methodSubtitle(method))
                                    .font(VuumType.caption)
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                            Spacer()
                            if payments.selectedMethod == method {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(VuumColor.brand)
                            } else if !payments.canSelect(method) {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if method.isMobileMoney, payments.linkedPhone(for: method) != nil {
                            Button("Unlink", role: .destructive) {
                                payments.unlinkMobileMoney(method)
                                syncTripPayment()
                            }
                        }
                    }
                }
            } header: {
                Text("Saved methods")
            } footer: {
                Text("Tap a method to set it as your default for upcoming trips. Link Mobile Money or add a card when prompted.")
            }

            Section("Cards") {
                if payments.cardLast4 != nil {
                    LabeledContent("Card", value: payments.cardDisplayLabel)
                    if let name = payments.cardHolderName, !name.isEmpty {
                        LabeledContent("Name", value: name)
                    }
                    Button("Remove card", role: .destructive) {
                        payments.removeCard()
                        syncTripPayment()
                    }
                } else {
                    Button("Add a card") { showAddCard = true }
                }
            }

            Section {
                NavigationLink {
                    PaymentHistoryView()
                } label: {
                    Label("Payment history", systemImage: "list.bullet.rectangle")
                }
                NavigationLink {
                    PaymentHubView(showsDoneButton: false)
                } label: {
                    Label("Payments & Wallet", systemImage: "creditcard.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle("Payment methods")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            payments.ensureValidSelection(for: market)
            syncTripPayment()
        }
        .sheet(item: $linkingMethod) { method in
            LinkMobileMoneyShellView(method: method)
                .environmentObject(payments)
                .environmentObject(session)
        }
        .sheet(isPresented: $showAddCard) {
            AddCardShellView()
                .environmentObject(payments)
        }
    }

    private func selectOrSetup(_ method: PaymentMethod) {
        if method.isMobileMoney, payments.linkedPhone(for: method) == nil {
            linkingMethod = method
            return
        }
        if method == .card, payments.cardLast4 == nil {
            showAddCard = true
            return
        }
        payments.select(method)
        syncTripPayment()
    }

    private func syncTripPayment() {
        if !tripSession.bookOnCompanyWallet {
            tripSession.paymentMethod = payments.selectedMethod
        }
    }
}

#Preview {
    NavigationStack {
        PaymentMethodsView()
    }
    .environmentObject(TripSession())
    .environmentObject(PaymentMethodStore())
    .environmentObject(SessionStore())
}
