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
    @FocusState private var nameFocused: Bool

    private var nameIsEmpty: Bool {
        draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(profile: FocusProfile?, draft: ProfileDraft) {
        self.profile = profile
        _draft = State(initialValue: draft)
    }

    private let iconOptions = [
        "briefcase.fill", "book.fill", "dumbbell.fill", "brain.head.profile",
        "laptopcomputer", "pencil.and.ruler.fill", "leaf.fill", "moon.stars.fill"
    ]
    // Quiet-spec tones: periwinkle, amber, green, purple, plus two calm extras.
    private let accentOptions = ["7C93E8", "D6A85C", "7FBE9A", "9B8AD6", "C88EA7", "6FB3C0"]

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                Form {
                    identitySection
                    accentSection
                    blockingSection
                    researchSection
                    lengthsSection
                    strictSection
                }
                .scrollContentBackground(.hidden)
                .tint(Color(hex: draft.accentHex))
            }
            .onAppear { if profile == nil { nameFocused = true } }
            .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("profile-save")
                        .disabled(nameIsEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
            .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
        }
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .accessibilityIdentifier("profile-name")
                .focused($nameFocused)
                .submitLabel(.done)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button { draft.iconName = icon } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(draft.iconName == icon ? Color(hex: "0A0B0E") : .primary)
                            .background(
                                draft.iconName == icon ? Color(hex: draft.accentHex) : ZTheme.Palette.glassFillRaised,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(icon.replacingOccurrences(of: ".", with: " ")) icon")
                    .accessibilityAddTraits(draft.iconName == icon ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Profile")
        } footer: {
            if nameIsEmpty {
                Label("Enter a name to save this profile.", systemImage: "pencil.line")
                    .foregroundStyle(ZTheme.Palette.streak)
            }
        }
    }

    private var accentSection: some View {
        Section("Accent") {
            HStack(spacing: 14) {
                ForEach(accentOptions, id: \.self) { hex in
                    Button { draft.accentHex = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if draft.accentHex == hex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color(hex: "0A0B0E"))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accent color")
                    .accessibilityAddTraits(draft.accentHex == hex ? [.isButton, .isSelected] : .isButton)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private var blockingSection: some View {
        Section {
            Toggle(isOn: $draft.blockAllApps) {
                Label("Block all apps", systemImage: "nosign")
            }
            if !draft.blockAllApps {
                Button {
                    showBlockPicker = true
                } label: {
                    LabeledContent("Blocked apps & sites") {
                        Text(countText(blockCount))
                    }
                }
            }
            Button {
                showAllowPicker = true
            } label: {
                LabeledContent(draft.blockAllApps ? "Allowed apps" : "Always allowed") {
                    Text(countText(draft.allow.applicationTokens.count))
                }
            }
        } header: {
            Text("Blocking")
        } footer: {
            Text(draft.blockAllApps
                 ? "Blocks every app and website during focus, except the allowed apps. Phone and system apps stay available."
                 : "Blocks only the apps, categories, and sites you choose.")
        }
    }

    private var researchSection: some View {
        Section {
            TextField("claude.ai, chatgpt.com, docs.google.com",
                      text: $draft.allowedWebDomains, axis: .vertical)
                .lineLimit(2...5)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
        } header: {
            Text("Research mode — allowed websites")
        } footer: {
            Text("When set, Safari is limited to ONLY these sites during focus (everything else on the web is blocked). Great for researching without entertainment sites. Leave empty to allow all websites.")
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
