import SwiftUI

struct TrustedContactsView: View {
    @EnvironmentObject private var store: TrustedContactsStore
    @State private var showEditor = false
    @State private var editing: TrustedContact?
    @State private var draftName = ""
    @State private var draftPhone = ""
    @State private var draftRelationship = ""
    @State private var draftIsDefault = false
    @State private var draftIsEmergency = true
    @State private var draftNotifyOnTripShare = true

    var body: some View {
        List {
            Section {
                Text("Trusted contacts can receive your live trip link and appear in emergency help. Add family or colleagues you travel with often.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Contacts") {
                if store.contacts.isEmpty {
                    VuumInlineEmptyRow(
                        systemImage: "person.crop.circle.badge.plus",
                        title: L10n.t("status.empty_contacts_title"),
                        message: L10n.t("status.empty_contacts_detail")
                    )
                } else {
                    ForEach(store.contacts) { contact in
                        Button {
                            beginEdit(contact)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(VuumColor.brandInk)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(contact.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        if contact.isDefault {
                                            Text("Default")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(VuumColor.brand.opacity(0.18), in: Capsule())
                                        }
                                    }
                                    Text(contact.displayPhone)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(contact.relationship)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    HStack(spacing: 8) {
                                        if contact.isEmergency {
                                            Label("Emergency", systemImage: "cross.circle.fill")
                                        }
                                        if contact.notifyOnTripShare {
                                            Label("Trip share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(VuumColor.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.remove(id: contact.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if !contact.isDefault {
                                Button {
                                    store.setDefault(id: contact.id)
                                } label: {
                                    Label("Default", systemImage: "star")
                                }
                                .tint(VuumColor.brandInk)
                            }
                        }
                    }
                    .onDelete(perform: store.remove(at:))
                }
            }

            Section {
                Button {
                    beginAdd()
                } label: {
                    Label("Add trusted contact", systemImage: "plus.circle")
                }
                .disabled(!store.canAddMore)
            } footer: {
                Text("You can save up to \(TrustedContactsStore.maxContacts) trusted contacts. Default contacts are prompted first when sharing a trip.")
            }
        }
        .navigationTitle("Trusted contacts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            editorSheet
        }
    }

    private var editorSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $draftName)
                        .textContentType(.name)
                    TextField("Mobile number", text: $draftPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Relationship", text: $draftRelationship)
                        .textContentType(.organizationName)
                }

                Section("Safety") {
                    Toggle("Default trip-share contact", isOn: $draftIsDefault)
                    Toggle("Emergency contact", isOn: $draftIsEmergency)
                    Toggle("Remind me to share trips", isOn: $draftNotifyOnTripShare)
                }
            }
            .navigationTitle(editing == nil ? "Add contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDraft() }
                        .disabled(!canSaveDraft)
                }
                if editing != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete contact", role: .destructive) {
                            if let editing {
                                store.remove(id: editing.id)
                            }
                            showEditor = false
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSaveDraft: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draftPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func beginAdd() {
        editing = nil
        draftName = ""
        draftPhone = ""
        draftRelationship = ""
        draftIsDefault = store.contacts.isEmpty
        draftIsEmergency = true
        draftNotifyOnTripShare = true
        showEditor = true
    }

    private func beginEdit(_ contact: TrustedContact) {
        editing = contact
        draftName = contact.name
        draftPhone = contact.phone
        draftRelationship = contact.relationship
        draftIsDefault = contact.isDefault
        draftIsEmergency = contact.isEmergency
        draftNotifyOnTripShare = contact.notifyOnTripShare
        showEditor = true
    }

    private func saveDraft() {
        if var existing = editing {
            existing.name = draftName
            existing.phone = draftPhone
            existing.relationship = draftRelationship
            existing.isDefault = draftIsDefault
            existing.isEmergency = draftIsEmergency
            existing.notifyOnTripShare = draftNotifyOnTripShare
            store.update(existing)
        } else {
            store.add(
                name: draftName,
                phone: draftPhone,
                relationship: draftRelationship,
                isDefault: draftIsDefault,
                isEmergency: draftIsEmergency,
                notifyOnTripShare: draftNotifyOnTripShare
            )
        }
        showEditor = false
    }
}
