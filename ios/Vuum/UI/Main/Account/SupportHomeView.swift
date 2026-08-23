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
                        .font(.system(size: 22, weight: .bold))
                    Text("FAQs, trip reports, lost items, and Congo Mobility contact options.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No open or pending tickets")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Submitted requests appear here until you mark them resolved.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
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
                    .font(.system(size: 14, weight: .semibold))
                }
            }

            Section("Contact") {
                LabeledContent("Hours", value: SupportContact.hours)
                Text(SupportContact.operatorName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.large)
    }
}
