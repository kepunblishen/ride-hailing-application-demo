import SwiftUI

/// Account entry for Help — ticket snapshot plus the full support center.
struct SupportHomeView: View {
    @ObservedObject private var store = SupportTicketStore.shared

    private var activeTickets: [SupportTicket] {
        (store.openTickets + store.pendingTickets)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Help & support")
                        .font(VuumType.title)
                        .foregroundStyle(VuumColor.primaryText)
                    Text("FAQs, trip reports, lost items, and Congo Mobility contact options.")
                        .font(VuumType.callout)
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(.vertical, 4)
            }

            Section("Quick actions") {
                NavigationLink {
                    SupportCenterView()
                } label: {
                    Label("Help Center", systemImage: "questionmark.circle.fill")
                }

                if let phoneURL = SupportContact.phoneURL {
                    Link(destination: phoneURL) {
                        Label("Call support", systemImage: "phone.fill")
                    }
                }

                NavigationLink {
                    SupportCenterView()
                } label: {
                    Label("Report a trip issue", systemImage: "car.side")
                }

                NavigationLink {
                    USSDBookingView()
                } label: {
                    Label("Book by USSD", systemImage: "phone.arrow.up.right")
                }
            }

            Section("Active tickets") {
                if activeTickets.isEmpty {
                    VuumInlineEmptyRow(
                        systemImage: "ticket",
                        title: L10n.t("status.empty_support_title"),
                        message: L10n.t("status.empty_support_detail")
                    )
                } else {
                    ForEach(activeTickets.prefix(5)) { ticket in
                        NavigationLink {
                            SupportTicketDetailView(ticketID: ticket.id)
                        } label: {
                            SupportTicketRow(ticket: ticket)
                        }
                    }
                    NavigationLink("View all in Help Center") {
                        SupportCenterView()
                    }
                    .font(VuumType.callout)
                }
            }

            Section("Contact") {
                LabeledContent("Hours", value: SupportContact.hours)
                Text(SupportContact.operatorName)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.large)
    }
}
