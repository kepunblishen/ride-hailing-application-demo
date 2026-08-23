import SwiftUI

/// Corporate / VIP executive transfer with optional meet-and-greet instructions for the driver.
struct ExecutiveProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var travellerName = ""
    @State private var tripPurpose = ""
    @State private var meetAndGreet = true
    @State private var nameBoard = true
    @State private var doorInstruction: DoorMeetInstruction = .arrivals
    @State private var customDoorNote = ""
    @State private var scheduleEnabled = false
    @State private var scheduleAt = Date().addingTimeInterval(3_600)

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.executive(
            distanceMeters: meters,
            meetAndGreet: meetAndGreet
        )
    }

    private var canConfirm: Bool {
        !travellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var doorInstructionText: String {
        switch doorInstruction {
        case .arrivals:
            return "Meet at arrivals with name board"
        case .lobby:
            return "Meet in hotel / building lobby"
        case .curbside:
            return "Meet curbside at main entrance"
        case .custom:
            let note = customDoorNote.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? "Meet at agreed door / gate" : note
        }
    }

    private var composedNotes: String {
        var parts: [String] = ["Executive transfer"]
        let purpose = tripPurpose.trimmingCharacters(in: .whitespacesAndNewlines)
        if !purpose.isEmpty {
            parts.append("Purpose: \(purpose)")
        }
        if meetAndGreet {
            parts.append("Meet & greet")
            if nameBoard {
                let board = travellerName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !board.isEmpty {
                    parts.append("Name board: \(board)")
                }
            }
            parts.append(doorInstructionText)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: "Executive",
                subtitle: "Premium cars, vetted drivers, and meet-and-greet pickup for VIP transfers.",
                symbol: "crown.fill",
                confirmTitle: "Continue to book",
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate,
                canConfirm: canConfirm
            ) {
                Section("Traveller") {
                    TextField("Traveller name", text: $travellerName)
                        .textContentType(.name)
                    TextField("Trip purpose (optional)", text: $tripPurpose)
                }

                Section("Meet-and-greet") {
                    Toggle("Meet-and-greet pickup", isOn: $meetAndGreet)

                    if meetAndGreet {
                        Toggle("Driver holds name board", isOn: $nameBoard)

                        Picker("Meet location", selection: $doorInstruction) {
                            ForEach(DoorMeetInstruction.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        if doorInstruction == .custom {
                            TextField("Door / gate instructions", text: $customDoorNote)
                        }

                        Text("About \(VehiclePickupETA.largeXXLMinutes) min to pickup · premium fare.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pickup time") {
                    Toggle("Schedule for later", isOn: $scheduleEnabled)
                    if scheduleEnabled {
                        DatePicker(
                            "Pickup",
                            selection: $scheduleAt,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            } onConfirm: {
                tripSession.startExecutiveMeetAndGreetBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    travellerName: travellerName,
                    tripPurpose: tripPurpose,
                    meetAndGreet: meetAndGreet,
                    nameBoard: nameBoard,
                    doorInstruction: doorInstructionText,
                    scheduleAt: scheduleEnabled ? scheduleAt : nil,
                    packageNotes: composedNotes,
                    injectTier: estimate
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle("Executive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { seedPlaces() }
        }
        .presentationDetents([.medium, .large])
    }

    private func seedPlaces() {
        let market: AppLocale.Market = AppLocale.current == .kenya ? .kenya : .drc
        let account = MockCorporate.miningCo
        pickup = tripSession.pickup
        dropoff = MockPlaces.destinations(for: market).first ?? dropoff
        if travellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            travellerName = tripSession.passengerName.isEmpty
                ? account.employeeRole
                : tripSession.passengerName
        }
        meetAndGreet = tripSession.meetAndGreetEnabled || account.meetAndGreetDefault
    }
}

enum DoorMeetInstruction: String, CaseIterable, Identifiable {
    case arrivals
    case lobby
    case curbside
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .arrivals: return "Arrivals / terminal"
        case .lobby: return "Lobby"
        case .curbside: return "Curbside entrance"
        case .custom: return "Custom instructions"
        }
    }
}
