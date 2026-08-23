import SwiftUI
import UIKit

/// In-trip message thread with the assigned driver. Backed by `TripSession.chatMessages`.
struct DriverChatView: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    private var driverName: String {
        tripSession.activeTrip?.driver.name ?? "Driver"
    }

    private var quickReplies: [String] {
        switch tripSession.phase {
        case .driverArrived:
            return ["I'm outside", "Coming now", "Look for me here", "One minute"]
        case .inTrip:
            return ["Thanks", "Please use AC", "Quiet ride please", "Drop at the gate"]
        default:
            return ["I'm outside", "I'll be right there", "Where are you?", "Coming now"]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                driverHeader

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(tripSession.chatMessages) { message in
                                chatBubble(message)
                                    .id(message.id)
                            }
                            if tripSession.driverIsTyping {
                                typingIndicator
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onAppear {
                        scrollToLatest(proxy: proxy, animated: false)
                    }
                    .onChange(of: tripSession.chatMessages.count) { _, _ in
                        tripSession.markChatRead()
                        scrollToLatest(proxy: proxy, animated: true)
                    }
                    .onChange(of: tripSession.driverIsTyping) { _, typing in
                        if typing {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()
                composer
            }
            .background(VuumColor.pageBackground.ignoresSafeArea())
            .navigationTitle(driverName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        DriverCallHelper.placeCall(to: tripSession.activeTrip?.driver.phone)
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                    }
                    .accessibilityLabel("Call driver")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                tripSession.setChatPresented(true)
                composerFocused = true
            }
            .onDisappear {
                tripSession.setChatPresented(false)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var driverHeader: some View {
        HStack(spacing: 12) {
            if let driver = tripSession.activeTrip?.driver {
                DriverAvatarView(driver: driver, size: 40)
            } else {
                Circle()
                    .fill(VuumColor.brand.opacity(0.22))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(driverName.prefix(1)))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VuumColor.primaryText)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(driverName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                if let trip = tripSession.activeTrip {
                    Text("\(trip.driver.vehicleMakeModel) · \(trip.driver.plate)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Button {
                DriverCallHelper.placeCall(to: tripSession.activeTrip?.driver.phone)
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 36, height: 36)
                    .background(VuumColor.brand.opacity(0.35), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Call driver")
            .accessibilityHint("Places a phone call to your driver")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VuumColor.sheetBackground)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickReplies, id: \.self) { reply in
                        Button {
                            tripSession.sendChat(reply)
                        } label: {
                            Text(reply)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.primaryText)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(VuumColor.chipBackground, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message \(driverName)", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? VuumColor.secondaryText
                                : VuumColor.brand
                        )
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
                .accessibilityHint("Sends your message to the driver")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .padding(.top, 10)
        .VuumChromeMaterialBackground()
    }

    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(VuumColor.secondaryText.opacity(0.55))
                        .frame(width: 6, height: 6)
                        .offset(y: tripSession.driverIsTyping ? (index == 1 ? -2 : 0) : 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 48)
        }
        .accessibilityLabel("\(driverName) is typing")
    }

    @ViewBuilder
    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isRider { Spacer(minLength: 48) }
            VStack(alignment: message.isRider ? .trailing : .leading, spacing: 4) {
                if !message.isRider {
                    Text(message.sender)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundStyle(message.isRider ? VuumColor.accentOn : VuumColor.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isRider ? VuumColor.emphasizedFill : VuumColor.chipBackground,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            if !message.isRider { Spacer(minLength: 48) }
        }
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        tripSession.sendChat(text)
    }

    private func scrollToLatest(proxy: ScrollViewProxy, animated: Bool) {
        let target = tripSession.driverIsTyping
            ? "typing"
            : tripSession.chatMessages.last?.id
        guard let target else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

enum DriverCallHelper {
    /// Builds a `tel:` URL from an E.164-style or local number. Returns nil when empty / unusable.
    static func telURL(for phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(digits)")
    }

    /// Opens Phone if a number exists; otherwise returns silently (no alert).
    @MainActor
    static func placeCall(to phone: String?) {
        guard let url = telURL(for: phone) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
