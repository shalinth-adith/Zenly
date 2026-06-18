//
//  ProfilesView.swift
//  Zenly
//
//  Lists focus profiles (Work / Study / Gym + custom). Tap to make active;
//  swipe to edit or delete. The active profile is what Home starts a session from.
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
            List {
                ForEach(store.profiles, id: \.objectID) { profile in
                    ProfileRow(profile: profile, isActive: profile.id == store.activeProfileID)
                        .contentShape(Rectangle())
                        .onTapGesture { store.setActive(profile) }
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
                            .tint(.indigo)
                        }
                }
            }
            .navigationTitle("Profiles")
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                }
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

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: profile.iconName ?? "brain.head.profile")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color(hex: profile.accentHex ?? "5C6BFA"), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "Untitled")
                    .font(.headline)
                Text(lengthSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var lengthSummary: String {
        let focus = "\(profile.focusMinutes) min focus"
        let brk = profile.breakMinutes > 0 ? " · \(profile.breakMinutes) min break" : ""
        let strict = profile.isStrict ? " · strict" : ""
        return focus + brk + strict
    }
}
