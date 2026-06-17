//
//  ProfileEditView.swift
//  Zenly
//
//  Create or edit a focus profile: name, icon, accent, blocklist/allowlist,
//  focus/break lengths, and strict mode.
//

import SwiftUI
import FamilyControls

struct ProfileEditView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// nil = creating a new profile.
    let profile: FocusProfile?
    @State private var draft: ProfileDraft
    @State private var showBlockPicker = false
    @State private var showAllowPicker = false

    init(profile: FocusProfile?, draft: ProfileDraft) {
        self.profile = profile
        _draft = State(initialValue: draft)
    }

    private let iconOptions = [
        "briefcase.fill", "book.fill", "dumbbell.fill", "brain.head.profile",
        "laptopcomputer", "pencil.and.ruler.fill", "leaf.fill", "moon.stars.fill"
    ]
    private let accentOptions = ["5C6BFA", "34C759", "FF9F0A", "FF375F", "AF52DE", "00C7BE"]

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                accentSection
                blockingSection
                lengthsSection
                strictSection
            }
            .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
            .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section("Profile") {
            TextField("Name", text: $draft.name)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(iconOptions, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(draft.iconName == icon ? .white : .primary)
                        .background(
                            draft.iconName == icon ? Color(hex: draft.accentHex) : Color(.secondarySystemFill),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .onTapGesture { draft.iconName = icon }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var accentSection: some View {
        Section("Accent") {
            HStack(spacing: 14) {
                ForEach(accentOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if draft.accentHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .onTapGesture { draft.accentHex = hex }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var blockingSection: some View {
        Section("Blocking") {
            Button {
                showBlockPicker = true
            } label: {
                LabeledContent("Blocked apps & sites") {
                    Text(countText(blockCount))
                }
            }
            Button {
                showAllowPicker = true
            } label: {
                LabeledContent("Always allowed") {
                    Text(countText(draft.allow.applicationTokens.count))
                }
            }
        }
    }

    private var lengthsSection: some View {
        Section("Session") {
            Stepper(value: $draft.focusMinutes, in: 5...120, step: 5) {
                LabeledContent("Focus", value: "\(draft.focusMinutes) min")
            }
            Stepper(value: $draft.breakMinutes, in: 0...30, step: 5) {
                LabeledContent("Break", value: draft.breakMinutes > 0 ? "\(draft.breakMinutes) min" : "None")
            }
        }
    }

    private var strictSection: some View {
        Section {
            Toggle(isOn: $draft.isStrict) {
                Label("Strict mode", systemImage: "lock.shield")
            }
        } footer: {
            Text("Requires a 5-second delay and confirmation before ending a session early.")
        }
    }

    // MARK: - Helpers

    private var blockCount: Int {
        draft.block.applicationTokens.count
            + draft.block.categoryTokens.count
            + draft.block.webDomainTokens.count
    }

    private func countText(_ count: Int) -> String {
        count == 0 ? "None" : "\(count)"
    }

    private func save() {
        if let profile {
            store.update(profile, with: draft)
        } else {
            store.create(from: draft)
        }
        dismiss()
    }
}
