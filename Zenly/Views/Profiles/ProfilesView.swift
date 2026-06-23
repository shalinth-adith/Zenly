//
//  ProfilesView.swift
//  Zenly
//
//  Lists focus profiles (Work / Study / Gym + custom). Tap to make active;
//  swipe to edit or delete. The active profile is what Home starts a session from.
//
//  Redesign: glass profile cards on the aurora with an active glow (Claude
//  Design spec, Zenly.dc.html). Logic, swipe actions, and editing unchanged.
//

import SwiftUI

struct ProfilesView: View {
    @Environment(ProfileStore.self) private var store
    @State private var editing: EditTarget?
    @State private var pendingDelete: FocusProfile?

    enum EditTarget: Identifiable {
        case new
        case existing(FocusProfile)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let profile): return profile.objectID.uriRepresentation().absoluteString
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                List {
                    ZenlyScreenTitle(title: "Profiles",
                                     subtitle: "Each profile blocks a different set of apps and remembers its own default length.")
                        .plainRow()
                        .padding(.bottom, 4)

                    ForEach(store.profiles, id: \.objectID) { profile in
                        ProfileRow(profile: profile, isActive: profile.id == store.activeProfileID)
                            .contentShape(Rectangle())
                            .onTapGesture { Haptics.light(); store.setActive(profile) }
                            .plainRow()
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = profile
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editing = .existing(profile)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(ZTheme.Palette.brand)
                            }
                    }

                    DashedActionButton(title: "New Profile") { editing = .new }
                        .plainRow()
                        .padding(.top, 4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Delete \u{201C}\(pendingDelete?.name ?? "this profile")\u{201D}?",
                isPresented: Binding(get: { pendingDelete != nil },
                                     set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let pendingDelete { store.delete(pendingDelete) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
            .sheet(item: $editing) { target in
                switch target {
                case .new:
                    ProfileEditView(profile: nil, draft: ProfileDraft())
                case .existing(let profile):
                    ProfileEditView(profile: profile, draft: store.draft(from: profile))
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: FocusProfile
    let isActive: Bool

    private var accent: Color { Color(hex: profile.accentHex ?? "1A3FA8") }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemImage: profile.iconName ?? "brain.head.profile", color: accent, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "Untitled")
                    .font(ZTheme.Font.display(17, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(lengthSummary)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }

            Spacer()

            if isActive {
                Text("ACTIVE")
                    .font(ZTheme.Font.body(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ZTheme.Palette.brandGlow)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(ZTheme.Palette.text(0.4))
        }
        .glassCard(padding: ZTheme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZTheme.Radius.card, style: .continuous)
                .strokeBorder(isActive ? accent : .clear, lineWidth: 1.5)
                .shadow(color: isActive ? accent.opacity(0.4) : .clear, radius: 14)
        )
    }

    private var lengthSummary: String {
        let focus = "\(profile.focusMinutes) min focus"
        let brk = profile.breakMinutes > 0 ? " · \(profile.breakMinutes) min break" : ""
        let strict = profile.isStrict ? " · strict" : ""
        return focus + brk + strict
    }
}

/// Strip the system list-row chrome so a glass card can sit directly on aurora.
extension View {
    func plainRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: ZTheme.Spacing.lg,
                                      bottom: 6, trailing: ZTheme.Spacing.lg))
    }
}
