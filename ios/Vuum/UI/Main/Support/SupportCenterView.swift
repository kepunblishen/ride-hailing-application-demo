import SwiftUI

// MARK: - Categories & FAQ

enum SupportCategory: String, CaseIterable, Identifiable, Codable {
    case myDriver
    case riderExperience
    case payment
    case fareDispute
    case lostItem
    case safety
    case cancellation
    case scheduledRide
    case account
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myDriver: return "My driver"
        case .riderExperience: return "My rider experience"
        case .payment: return "Payment"
        case .fareDispute: return "Fare dispute"
        case .lostItem: return "Lost item"
        case .safety: return "Safety"
        case .cancellation: return "Cancellation"
        case .scheduledRide: return "Scheduled ride"
        case .account: return "Account"
        case .other: return "Other"
        }
    }

    var subtitle: String {
        switch self {
        case .myDriver: return "Conduct, vehicle, pickup issues"
        case .riderExperience: return "Comfort, cleanliness, service"
        case .payment: return "Charges, wallets, Mobile Money"
        case .fareDispute: return "Unexpected totals or route fare"
        case .lostItem: return "Left something in a vehicle"
        case .safety: return "Emergency help and trip sharing"
        case .cancellation: return "Fees, no-shows, cancel reasons"
        case .scheduledRide: return "Reservations and reminders"
        case .account: return "Profile, phone number, sign-in"
        case .other: return "Anything else we can help with"
        }
    }

    var systemImage: String {
        switch self {
        case .myDriver: return "person.crop.circle.badge.exclamationmark"
        case .riderExperience: return "star.bubble"
        case .payment: return "creditcard"
        case .fareDispute: return "coloncurrencysign.circle"
        case .lostItem: return "bag"
        case .safety: return "shield.lefthalf.filled"
        case .cancellation: return "xmark.circle"
        case .scheduledRide: return "calendar"
        case .account: return "person.crop.circle"
        case .other: return "ellipsis.circle"
        }
    }

    /// Categories that should offer trip selection before filing.
    var requiresTripSelection: Bool {
        switch self {
        case .myDriver, .payment, .fareDispute, .lostItem, .cancellation, .riderExperience:
            return true
        case .safety, .scheduledRide, .account, .other:
            return false
        }
    }

    var issueOptions: [String] {
        switch self {
        case .myDriver:
            return ["Driver never arrived", "Rude or unsafe behavior", "Wrong vehicle", "Driving concern", "Other driver issue"]
        case .riderExperience:
            return ["Vehicle cleanliness", "Comfort", "Music or temperature", "Communication", "Other"]
        case .payment:
            return ["Charged twice", "Payment failed", "Wrong method charged", "Refund request", "Other payment issue"]
        case .fareDispute:
            return ["Fare higher than estimate", "Unexpected waiting charge", "Wrong route charged", "Promo not applied", "Other fare issue"]
        case .lostItem:
            return ["Phone or electronics", "Bag or wallet", "Personal item", "Work equipment", "Other"]
        case .safety:
            return ["Felt unsafe", "Incident during trip", "Share-trip concern", "SOS follow-up", "Other safety issue"]
        case .cancellation:
            return ["Cancellation fee review", "Driver cancelled", "I cancelled by mistake", "No-show", "Other"]
        case .scheduledRide:
            return ["Change reservation", "Driver not assigned", "Reminder issue", "Cancel reservation", "Other"]
        case .account:
            return ["Update phone number", "Name or profile", "Sign-in trouble", "Delete account request", "Other"]
        case .other:
            return ["General question", "Feedback", "Partnership", "Other"]
        }
    }
}

struct SupportFAQItem: Identifiable, Hashable {
    let id: String
    let category: SupportCategory
    let question: String
    let answer: String
}

enum SupportFAQCatalog {
    static let all: [SupportFAQItem] = [
        SupportFAQItem(
            id: "drv-noshow",
            category: .myDriver,
            question: "My driver never arrived",
            answer: "Cancel the trip if it is still open, then request another ride. File a ticket under My driver so we can review the assignment and any fees."
        ),
        SupportFAQItem(
            id: "drv-conduct",
            category: .myDriver,
            question: "How do I report driver conduct?",
            answer: "Open Help → My driver, select the trip, describe what happened, and submit. Trust & Safety reviews every report."
        ),
        SupportFAQItem(
            id: "exp-clean",
            category: .riderExperience,
            question: "The vehicle was not clean",
            answer: "Rate the trip and send a rider-experience ticket with the trip time. We use that feedback when coaching partners."
        ),
        SupportFAQItem(
            id: "pay-momo",
            category: .payment,
            question: "How does Mobile Money work?",
            answer: "Add Mobile Money under Wallet, then select it at checkout when your trip ends. Keep enough balance for the fare plus any tip."
        ),
        SupportFAQItem(
            id: "pay-receipt",
            category: .payment,
            question: "Where do I find trip receipts?",
            answer: "Open Activity and select a completed trip. Each receipt includes pickup, dropoff, product, and the fare breakdown."
        ),
        SupportFAQItem(
            id: "fare-route",
            category: .fareDispute,
            question: "The driver took a longer route",
            answer: "Fares use distance and time for your selected product. Open Fare dispute, pick the trip, and our team will review the route against the receipt."
        ),
        SupportFAQItem(
            id: "lost-report",
            category: .lostItem,
            question: "I left something in the car",
            answer: "Use Lost item under Help, select the trip, describe the item, and submit. We contact the driver and follow up by chat or phone."
        ),
        SupportFAQItem(
            id: "lost-time",
            category: .lostItem,
            question: "How long does a lost-item recovery take?",
            answer: "Most cases are reviewed within a few hours during operating hours in Lubumbashi and Kolwezi. Keep your phone nearby."
        ),
        SupportFAQItem(
            id: "safe-sos",
            category: .safety,
            question: "How do I get emergency help during a trip?",
            answer: "During an active trip, open Safety toolkit and use Request emergency help. You can also share live trip status with a trusted contact."
        ),
        SupportFAQItem(
            id: "cancel-fee",
            category: .cancellation,
            question: "Why was I charged a cancellation fee?",
            answer: "Fees may apply after a driver is assigned and on the way. Open Cancellation under Help with the trip selected and we will review the timing."
        ),
        SupportFAQItem(
            id: "sched-edit",
            category: .scheduledRide,
            question: "Can I change a reserved ride?",
            answer: "Open Services or Activity for upcoming rides to edit or cancel. Contact support if the reservation window has closed."
        ),
        SupportFAQItem(
            id: "acct-phone",
            category: .account,
            question: "How do I update my phone number?",
            answer: "From Account, open your profile and request a number change. We verify the new number with a one-time code before it becomes your sign-in mobile."
        ),
    ]

    static func items(for category: SupportCategory) -> [SupportFAQItem] {
        all.filter { $0.category == category }
    }
}

// MARK: - Tickets

enum SupportTicketStatus: String, Codable, CaseIterable {
    case submitted
    case received
    case investigating
    case responseAvailable
    case resolved

    var title: String {
        switch self {
        case .submitted: return "Submitted"
        case .received: return "Received"
        case .investigating: return "Investigating"
        case .responseAvailable: return "Response available"
        case .resolved: return "Resolved"
        }
    }

    var systemImage: String {
        switch self {
        case .submitted: return "paperplane.fill"
        case .received: return "tray.and.arrow.down.fill"
        case .investigating: return "magnifyingglass"
        case .responseAvailable: return "bubble.left.and.bubble.right.fill"
        case .resolved: return "checkmark.seal.fill"
        }
    }

    /// List grouping for the Help tickets section.
    var listBucket: SupportTicketBucket {
        switch self {
        case .submitted, .received:
            return .open
        case .investigating, .responseAvailable:
            return .pending
        case .resolved:
            return .resolved
        }
    }
}

enum SupportTicketBucket: String, CaseIterable, Identifiable {
    case open
    case pending
    case resolved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .resolved: return "Resolved"
        }
    }
}

struct SupportTicket: Identifiable, Codable, Equatable {
    let id: UUID
    var category: SupportCategory
    var issueLabel: String
    var subject: String
    var body: String
    var tripId: String?
    var tripSummary: String?
    var driverName: String?
    var vehicleSummary: String?
    var status: SupportTicketStatus
    var createdAt: Date
    var updatedAt: Date
    var agentResponse: String?

    init(
        id: UUID = UUID(),
        category: SupportCategory,
        issueLabel: String,
        subject: String,
        body: String,
        tripId: String? = nil,
        tripSummary: String? = nil,
        driverName: String? = nil,
        vehicleSummary: String? = nil,
        status: SupportTicketStatus = .submitted,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        agentResponse: String? = nil
    ) {
        self.id = id
        self.category = category
        self.issueLabel = issueLabel
        self.subject = subject
        self.body = body
        self.tripId = tripId
        self.tripSummary = tripSummary
        self.driverName = driverName
        self.vehicleSummary = vehicleSummary
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.agentResponse = agentResponse
    }
}

struct SupportChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case rider
        case agent
    }

    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class SupportTicketStore: ObservableObject {
    static let shared = SupportTicketStore()

    private enum Keys {
        static let tickets = "vuum.support.tickets"
        static let chat = "vuum.support.chatMessages"
    }

    @Published private(set) var tickets: [SupportTicket] = []
    @Published private(set) var chatMessages: [SupportChatMessage] = []

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var progressionTasks: [UUID: Task<Void, Never>] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        resumeOpenProgressions()
    }

    var openTickets: [SupportTicket] {
        tickets.filter { $0.status.listBucket == .open }
    }

    var pendingTickets: [SupportTicket] {
        tickets.filter { $0.status.listBucket == .pending }
    }

    var resolvedTickets: [SupportTicket] {
        tickets.filter { $0.status.listBucket == .resolved }
    }

    func tickets(in bucket: SupportTicketBucket) -> [SupportTicket] {
        tickets.filter { $0.status.listBucket == bucket }
    }

    func ticket(id: UUID) -> SupportTicket? {
        tickets.first { $0.id == id }
    }

    @discardableResult
    func submit(
        category: SupportCategory,
        issueLabel: String,
        subject: String,
        body: String,
        tripId: String? = nil,
        tripSummary: String? = nil,
        driverName: String? = nil,
        vehicleSummary: String? = nil
    ) -> SupportTicket? {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty, !trimmedBody.isEmpty else { return nil }

        let ticket = SupportTicket(
            category: category,
            issueLabel: issueLabel,
            subject: trimmedSubject,
            body: trimmedBody,
            tripId: tripId,
            tripSummary: tripSummary,
            driverName: driverName,
            vehicleSummary: vehicleSummary,
            status: .submitted
        )
        tickets.insert(ticket, at: 0)
        persistTickets()
        scheduleProgression(for: ticket.id, from: .submitted)
        return ticket
    }

    func markResolved(_ id: UUID) {
        guard let index = tickets.firstIndex(where: { $0.id == id }) else { return }
        progressionTasks[id]?.cancel()
        progressionTasks[id] = nil
        tickets[index].status = .resolved
        tickets[index].updatedAt = Date()
        if tickets[index].agentResponse == nil {
            tickets[index].agentResponse = "This ticket was marked resolved. Contact Congo Mobility again if you need more help."
        }
        persistTickets()
    }

    func appendChat(role: SupportChatMessage.Role, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatMessages.append(SupportChatMessage(role: role, text: trimmed))
        persistChat()
    }

    func ensureChatWelcome(riderFirstName: String) {
        guard chatMessages.isEmpty else { return }
        let name = riderFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = name.isEmpty
            ? "Hi — you’re connected to Vuum Support for Congo Mobility. How can we help with your ride today?"
            : "Hi \(name) — you’re connected to Vuum Support for Congo Mobility. How can we help with your ride today?"
        appendChat(role: .agent, text: greeting)
    }

    private func resumeOpenProgressions() {
        for ticket in tickets where ticket.status != .resolved && ticket.status != .responseAvailable {
            scheduleProgression(for: ticket.id, from: ticket.status)
        }
    }

    private func scheduleProgression(for id: UUID, from status: SupportTicketStatus) {
        progressionTasks[id]?.cancel()
        progressionTasks[id] = Task { @MainActor in
            defer { progressionTasks[id] = nil }

            var step = status
            if step == .submitted {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard !Task.isCancelled else { return }
                advance(id, to: .received, response: nil)
                step = .received
            }
            if step == .received {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                advance(
                    id,
                    to: .investigating,
                    response: "Congo Mobility support received your request and is reviewing the details."
                )
                step = .investigating
            }
            if step == .investigating {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                advance(id, to: .responseAvailable, response: agentReply(for: id))
            }
        }
    }

    private func agentReply(for id: UUID) -> String {
        guard let ticket = tickets.first(where: { $0.id == id }) else {
            return "Thanks for contacting Congo Mobility. We’ve reviewed your request and will follow up if anything else is needed."
        }
        switch ticket.category {
        case .lostItem:
            return "We’ve messaged the driver about your lost item. Keep this ticket open — we’ll update you when they respond."
        case .payment, .fareDispute:
            return "We’re reviewing the fare and payment records for this trip. You’ll see any adjustment on your next receipt update."
        case .safety:
            return "Trust & Safety has opened a priority review. If you’re still in danger, call local emergency services and use Request emergency help in the trip."
        case .cancellation:
            return "We’re checking cancellation timing against the free-cancel window. You’ll hear from us if a fee should be waived."
        case .myDriver, .riderExperience:
            return "Thanks for the report. Partner coaching reviews driver and vehicle feedback from trips like yours."
        default:
            return "Thanks for contacting Congo Mobility. We’ve reviewed your \(ticket.category.title.lowercased()) request and will follow up by chat or phone if needed."
        }
    }

    private func advance(_ id: UUID, to status: SupportTicketStatus, response: String?) {
        guard let index = tickets.firstIndex(where: { $0.id == id }) else { return }
        guard tickets[index].status != .resolved else { return }
        let order: [SupportTicketStatus] = [
            .submitted, .received, .investigating, .responseAvailable, .resolved,
        ]
        if let currentIdx = order.firstIndex(of: tickets[index].status),
           let nextIdx = order.firstIndex(of: status),
           nextIdx < currentIdx {
            return
        }
        tickets[index].status = status
        tickets[index].updatedAt = Date()
        if let response {
            tickets[index].agentResponse = response
        }
        persistTickets()
    }

    private func load() {
        if let data = defaults.data(forKey: Keys.tickets),
           let decoded = try? decoder.decode([SupportTicket].self, from: data) {
            tickets = decoded
        }
        if let data = defaults.data(forKey: Keys.chat),
           let decoded = try? decoder.decode([SupportChatMessage].self, from: data) {
            chatMessages = decoded
        }
    }

    private func persistTickets() {
        if let data = try? encoder.encode(tickets) {
            defaults.set(data, forKey: Keys.tickets)
        }
    }

    private func persistChat() {
        if let data = try? encoder.encode(chatMessages) {
            defaults.set(data, forKey: Keys.chat)
        }
    }
}

// MARK: - Contact

enum SupportContact {
    static let phoneDisplay = "+243 81 234 5678"
    static let phoneURL = URL(string: "tel:+243812345678")
    static let emailDisplay = "support@congomobility.cd"
    static let emailURL = URL(string: "mailto:support@congomobility.cd")
    static let hours = "Daily · 06:00–22:00 (Lubumbashi & Kolwezi)"
    static let operatorName = "Congo Mobility SARL"
}

// MARK: - Support center

struct SupportCenterView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var tripSession: TripSession
    @ObservedObject private var store = SupportTicketStore.shared
    @State private var showChat = false
    @State private var showComposer = false
    @State private var composerCategory: SupportCategory = .payment
    @State private var preselectedTrip: TripReceipt?
    @State private var ticketBucket: SupportTicketBucket = .open

    private var filteredTickets: [SupportTicket] {
        store.tickets(in: ticketBucket)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How can we help?")
                        .font(.system(size: 22, weight: .bold))
                    Text("Browse topics, open a ticket, or call Congo Mobility support.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }

            Section("Get help now") {
                Button {
                    showChat = true
                } label: {
                    Label("Chat with support", systemImage: "bubble.left.and.bubble.right.fill")
                }

                Button {
                    composerCategory = .payment
                    preselectedTrip = nil
                    showComposer = true
                } label: {
                    Label("Contact support", systemImage: "envelope.fill")
                }
            }

            Section("Topics") {
                ForEach(SupportCategory.allCases) { category in
                    NavigationLink {
                        SupportCategoryDetailView(
                            category: category,
                            onMessage: {
                                composerCategory = category
                                preselectedTrip = nil
                                showComposer = true
                            }
                        )
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(category.subtitle)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(VuumColor.brandInk)
                        }
                    }
                }
            }

            Section("Contact Congo Mobility") {
                if let phoneURL = SupportContact.phoneURL {
                    Link(destination: phoneURL) {
                        Label(SupportContact.phoneDisplay, systemImage: "phone.fill")
                    }
                }
                if let emailURL = SupportContact.emailURL {
                    Link(destination: emailURL) {
                        Label(SupportContact.emailDisplay, systemImage: "envelope")
                    }
                }
                LabeledContent("Hours", value: SupportContact.hours)
                Text(SupportContact.operatorName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Status", selection: $ticketBucket) {
                    ForEach(SupportTicketBucket.allCases) { bucket in
                        Text("\(bucket.title) (\(store.tickets(in: bucket).count))")
                            .tag(bucket)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)

                if store.tickets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        VuumInlineEmptyRow(
                            systemImage: "ticket",
                            title: L10n.t("status.empty_support_title"),
                            message: L10n.t("status.empty_support_detail")
                        )
                        Button("Open a ticket") {
                            composerCategory = .other
                            showComposer = true
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.vertical, 4)
                } else if filteredTickets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No \(ticketBucket.title.lowercased()) tickets")
                            .font(.system(size: 15, weight: .semibold))
                        Text(emptyBucketCopy)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(filteredTickets) { ticket in
                        NavigationLink {
                            SupportTicketDetailView(ticketID: ticket.id)
                        } label: {
                            SupportTicketRow(ticket: ticket)
                        }
                    }
                }
            } header: {
                Text("Your tickets")
            }
        }
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showChat) {
            SupportChatSheet(store: store, riderFirstName: session.firstName)
        }
        .sheet(isPresented: $showComposer) {
            SupportTicketComposerView(
                store: store,
                initialCategory: composerCategory,
                trips: tripSession.tripHistory,
                preselectedTrip: preselectedTrip
            )
        }
    }

    private var emptyBucketCopy: String {
        switch ticketBucket {
        case .open:
            return "New tickets show here until Congo Mobility starts investigating."
        case .pending:
            return "Tickets under review or with a support response appear here."
        case .resolved:
            return "Resolved tickets stay on this device for your records."
        }
    }
}

struct SupportTicketRow: View {
    let ticket: SupportTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(ticket.status.title, systemImage: ticket.status.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Text(ticket.status.listBucket.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(ticket.updatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(ticket.subject)
                .font(.system(size: 15, weight: .semibold))
            Text(ticket.category.title + " · " + ticket.issueLabel)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ticket.subject), \(ticket.status.title), \(ticket.status.listBucket.title)")
    }

    private var statusColor: Color {
        switch ticket.status.listBucket {
        case .open: return VuumColor.brandInk
        case .pending: return Color.orange
        case .resolved: return Color.green
        }
    }
}

struct SupportTicketDetailView: View {
    let ticketID: UUID
    @ObservedObject private var store = SupportTicketStore.shared

    private var ticket: SupportTicket? {
        store.ticket(id: ticketID)
    }

    var body: some View {
        Group {
            if let ticket {
                List {
                    Section("Status") {
                        Label(ticket.status.title, systemImage: ticket.status.systemImage)
                        LabeledContent("Group", value: ticket.status.listBucket.title)
                        LabeledContent("Opened", value: ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Updated", value: ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    Section("Request") {
                        LabeledContent("Topic", value: ticket.category.title)
                        LabeledContent("Issue", value: ticket.issueLabel)
                        Text(ticket.subject)
                            .font(.system(size: 16, weight: .semibold))
                        Text(ticket.body)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    if ticket.tripSummary != nil || ticket.driverName != nil {
                        Section("Trip") {
                            if let tripSummary = ticket.tripSummary {
                                Text(tripSummary)
                            }
                            if let driverName = ticket.driverName {
                                LabeledContent("Driver", value: driverName)
                            }
                            if let vehicle = ticket.vehicleSummary {
                                LabeledContent("Vehicle", value: vehicle)
                            }
                        }
                    }

                    if let response = ticket.agentResponse {
                        Section("Support response") {
                            Text(response)
                        }
                    }

                    if ticket.status != .resolved {
                        Section {
                            Button("Mark as resolved") {
                                store.markResolved(ticket.id)
                            }
                            .fontWeight(.semibold)
                        }
                    }

                    Section("Contact") {
                        if let phoneURL = SupportContact.phoneURL {
                            Link(destination: phoneURL) {
                                Label(SupportContact.phoneDisplay, systemImage: "phone.fill")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Ticket unavailable",
                    systemImage: "ticket",
                    description: Text("This support request is no longer on this device.")
                )
            }
        }
        .navigationTitle("Ticket")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Category & FAQ detail

struct SupportCategoryDetailView: View {
    let category: SupportCategory
    var onMessage: () -> Void

    private var faqs: [SupportFAQItem] {
        SupportFAQCatalog.items(for: category)
    }

    var body: some View {
        List {
            Section {
                Text(category.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if !faqs.isEmpty {
                Section("Common questions") {
                    ForEach(faqs) { item in
                        NavigationLink(item.question) {
                            SupportFAQDetailView(item: item, onMessage: onMessage)
                        }
                    }
                }
            }

            Section {
                Button(action: onMessage) {
                    Label("Report · \(category.title)", systemImage: "envelope")
                }
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportFAQDetailView: View {
    let item: SupportFAQItem
    var onMessage: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.question)
                    .font(.system(size: 22, weight: .bold))
                Text(item.answer)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onMessage) {
                    Label("Still need help? Open a ticket", systemImage: "envelope.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VuumColor.brandInk)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .navigationTitle(item.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .VuumPageBackground()
    }
}

// MARK: - Ticket composer (category → trip → issue → describe → submit)

struct SupportTicketComposerView: View {
    @ObservedObject var store: SupportTicketStore
    let initialCategory: SupportCategory
    let trips: [TripReceipt]
    var preselectedTrip: TripReceipt?
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var category: SupportCategory
    @State private var selectedTrip: TripReceipt?
    @State private var issueLabel = ""
    @State private var subject = ""
    @State private var body = ""
    @State private var didSend = false

    init(
        store: SupportTicketStore,
        initialCategory: SupportCategory,
        trips: [TripReceipt],
        preselectedTrip: TripReceipt? = nil
    ) {
        self.store = store
        self.initialCategory = initialCategory
        self.trips = trips
        self.preselectedTrip = preselectedTrip
        _category = State(initialValue: initialCategory)
        _selectedTrip = State(initialValue: preselectedTrip)
        if preselectedTrip != nil, initialCategory.requiresTripSelection {
            _step = State(initialValue: 2)
            _issueLabel = State(initialValue: "")
        }
    }

    private var needsTrip: Bool { category.requiresTripSelection }

    private var canContinueFromIssue: Bool {
        !issueLabel.isEmpty
    }

    private var canSubmit: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !issueLabel.isEmpty
            && (!needsTrip || selectedTrip != nil || trips.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case 0:
                    Section("Topic") {
                        Picker("Category", selection: $category) {
                            ForEach(SupportCategory.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .onChange(of: category) { _, _ in
                            issueLabel = ""
                            if !category.requiresTripSelection {
                                selectedTrip = nil
                            }
                        }
                    }
                case 1 where needsTrip:
                    Section("Select trip") {
                        if trips.isEmpty {
                            Text("No completed trips yet. You can still describe what happened on the next step.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(trips) { trip in
                                Button {
                                    selectedTrip = trip
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(trip.pickupName) → \(trip.dropoffName)")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(VuumColor.primaryText)
                                            Text("\(trip.driverName) · \(trip.date.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedTrip?.id == trip.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(VuumColor.brandInk)
                                        }
                                    }
                                }
                            }
                        }
                    }
                case needsTrip ? 2 : 1:
                    Section("What happened?") {
                        ForEach(category.issueOptions, id: \.self) { option in
                            Button {
                                issueLabel = option
                                if subject.isEmpty {
                                    subject = option
                                }
                            } label: {
                                HStack {
                                    Text(option)
                                        .foregroundStyle(VuumColor.primaryText)
                                    Spacer()
                                    if issueLabel == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(VuumColor.brandInk)
                                    }
                                }
                            }
                        }
                    }
                default:
                    Section("Describe") {
                        TextField("Subject", text: $subject)
                        TextField(
                            category == .lostItem
                                ? "Describe the item and where you may have left it"
                                : "Describe what happened",
                            text: $body,
                            axis: .vertical
                        )
                        .lineLimit(5...12)
                    }

                    if let trip = selectedTrip {
                        Section("Trip details") {
                            LabeledContent("Route", value: "\(trip.pickupName) → \(trip.dropoffName)")
                            LabeledContent("Driver", value: trip.driverName)
                            LabeledContent("Time", value: trip.date.formatted(date: .abbreviated, time: .shortened))
                            LabeledContent("Product", value: trip.tierName)
                        }
                    }

                    Section {
                        Text("Your ticket is saved on this device and queued for Congo Mobility support.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 0 ? "Cancel" : "Back") {
                        if step == 0 {
                            dismiss()
                        } else {
                            step -= 1
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLastStep {
                        Button("Submit") {
                            submitTicket()
                        }
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                    } else {
                        Button("Next") {
                            advance()
                        }
                        .disabled(!canAdvance)
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Ticket submitted", isPresented: $didSend) {
                Button("OK") { dismiss() }
            } message: {
                Text("We’ll follow up by chat or phone using the details on your account.")
            }
        }
        .presentationDetents([.large])
    }

    private var navigationTitle: String {
        if isLastStep { return "Submit ticket" }
        if step == 0 { return "Contact support" }
        if needsTrip && step == 1 { return "Select trip" }
        return "Choose issue"
    }

    private var isLastStep: Bool {
        let issueStep = needsTrip ? 2 : 1
        return step > issueStep
    }

    private var canAdvance: Bool {
        if step == 0 { return true }
        if needsTrip && step == 1 { return selectedTrip != nil || trips.isEmpty }
        let issueStep = needsTrip ? 2 : 1
        if step == issueStep { return canContinueFromIssue }
        return true
    }

    private func advance() {
        if needsTrip && step == 0 {
            step = 1
        } else if !needsTrip && step == 0 {
            step = 1
        } else {
            step += 1
        }
    }

    private func submitTicket() {
        let trip = selectedTrip
        let summary = trip.map { "\($0.pickupName) → \($0.dropoffName) · \($0.date.formatted(date: .abbreviated, time: .shortened))" }
        _ = store.submit(
            category: category,
            issueLabel: issueLabel.isEmpty ? category.title : issueLabel,
            subject: subject,
            body: body,
            tripId: trip?.id,
            tripSummary: summary,
            driverName: trip?.driverName,
            vehicleSummary: trip.map { $0.tierName }
        )
        didSend = true
    }
}

// MARK: - Lost item (trip-scoped entry)

struct LostItemReportView: View {
    let receipt: TripReceipt
    @ObservedObject private var store = SupportTicketStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var descriptionText = ""
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    LabeledContent("Route", value: "\(receipt.pickupName) → \(receipt.dropoffName)")
                    LabeledContent("Driver", value: receipt.driverName)
                    LabeledContent("Product", value: receipt.tierName)
                    LabeledContent("Time", value: receipt.date.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Item") {
                    TextField("Describe the item", text: $descriptionText, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section {
                    Text("We’ll contact the driver and follow up using your account phone number.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let phoneURL = SupportContact.phoneURL {
                        Link(destination: phoneURL) {
                            Label(SupportContact.phoneDisplay, systemImage: "phone.fill")
                        }
                    }
                }
            }
            .navigationTitle("Lost item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        _ = store.submit(
                            category: .lostItem,
                            issueLabel: "Personal item",
                            subject: "Lost item on \(receipt.dropoffName) trip",
                            body: descriptionText,
                            tripId: receipt.id,
                            tripSummary: "\(receipt.pickupName) → \(receipt.dropoffName)",
                            driverName: receipt.driverName,
                            vehicleSummary: receipt.tierName
                        )
                        didSend = true
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .alert("Request submitted", isPresented: $didSend) {
                Button("OK") { dismiss() }
            } message: {
                Text("Support will follow up about your lost item.")
            }
        }
    }
}

// MARK: - Chat with support

struct SupportChatSheet: View {
    @ObservedObject var store: SupportTicketStore
    let riderFirstName: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(store.chatMessages) { message in
                                chatBubble(message)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: store.chatMessages.count) { _, _ in
                        if let last = store.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Type a message", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 14))
                        .focused($composerFocused)

                    Button {
                        sendDraft()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.secondary
                                    : VuumColor.brandInk
                            )
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Support chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                store.ensureChatWelcome(riderFirstName: riderFirstName)
                composerFocused = true
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func chatBubble(_ message: SupportChatMessage) -> some View {
        let isRider = message.role == .rider
        HStack {
            if isRider { Spacer(minLength: 48) }
            VStack(alignment: isRider ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(isRider ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isRider ? VuumColor.brandInk : VuumColor.chipBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if !isRider { Spacer(minLength: 48) }
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.appendChat(role: .rider, text: text)
        draft = ""
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            store.appendChat(role: .agent, text: agentReply(for: text))
        }
    }

    private func agentReply(for riderText: String) -> String {
        let lower = riderText.lowercased()
        if lower.contains("lost") || lower.contains("left") || lower.contains("bag") {
            return "Sorry about that. Share the approximate trip time and a description of the item — we’ll contact the driver and update you here."
        }
        if lower.contains("pay") || lower.contains("fare") || lower.contains("cdf") || lower.contains("money") {
            return "Thanks for the details. Our payments team can review the fare on your receipt. You can also open Activity for the trip total."
        }
        if lower.contains("safe") || lower.contains("emergency") || lower.contains("help") {
            return "If you’re in danger right now, use Safety toolkit → Request emergency help, or call local emergency services. I’m here for non-urgent follow-up."
        }
        if lower.contains("cancel") || lower.contains("driver") || lower.contains("trip") {
            return "Got it. Tell us the pickup area and what went wrong on the trip, and we’ll look into the assignment and any fees."
        }
        return "Thanks — we’ve logged your message for Congo Mobility support. A specialist will continue here or call \(SupportContact.phoneDisplay) if we need more details."
    }
}
