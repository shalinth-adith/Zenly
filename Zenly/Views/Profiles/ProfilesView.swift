//
//  ProfilesView.swift
//  Zenly
//
//  Quiet spec, screens 20 ("Profiles · delete") and 21 ("Profiles · can't
//  delete").
//
//  The list itself is the comp's: a 24pt title with "Reorder" beside it, one
//  explanatory line, then rows separated by hairlines rather than boxed in
//  cards. Only the running profile is given a surface — a tone-soft rounded
//  card with an ACTIVE eyebrow — so on a screen where everything is neutral,
//  the one thing that is happening is the one thing that is coloured.
//
//  This replaced glass cards on an aurora background, which is why the icon
//  tiles are gone: the comp identifies a profile by its name and its length,
//  and lets the tone carry the rest.
//
//  Deleting is two screens because there are two answers:
//
//  20 — a bottom sheet over a dimmed list. The question is "Delete 'Late
//       night'?" and the sentence under it exists to take the fear out of
//       answering: the profile goes, the sessions and the streak stay.
//  21 — no sheet at all. A profile that is mid-session cannot be deleted, and
//       the comp says so *in the row itself* rather than as an alert. Nothing
//       is dismissed, nothing is lost, and the way out ("Go to session") is
//       right there under the sentence.
//

import CoreData
import SwiftUI

struct ProfilesView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(FocusSessionController.self) private var session
    @Environment(AnalyticsService.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    @State private var showNewProfile = false
    @State private var pendingDelete: FocusProfile?
    @State private var editMode: EditMode = .inactive
    /// The profile whose "can't delete while it's running" note is showing.
    /// Screen 21 is a state of the row, not a screen of its own.
    @State private var blockedDelete: NSManagedObjectID?
    /// The profile pushed as screen 20b. Held as an object ID rather than the
    /// managed object so the destination can re-resolve it every render and
    /// fall away cleanly the moment it is deleted.
    @State private var detail: ProfileRef?

    /// An `NSManagedObject` has an optional `id`, so it cannot be `Identifiable`
    /// itself. Its object ID can.
    struct ProfileRef: Identifiable, Hashable {
        let objectID: NSManagedObjectID
        var id: NSManagedObjectID { objectID }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZTheme.Palette.night.ignoresSafeArea()

                VStack(spacing: 0) {
                    backBar
                    List {
                        header
                        rows
                        newProfileButton
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, $editMode)
                }

                // The comp dims the list to rgba(0,0,0,.45) behind the sheet.
                // Drawn here rather than left to the system: at this detent the
                // sheet's own background (#07080A) is within a couple of values
                // of the page it sits on, so without the scrim the card has no
                // edge and the list reads as still being in play.
                if pendingDelete != nil {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(ZTheme.Motion.smooth, value: pendingDelete != nil)
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            // Screen 20b. The row's chevron finally leads somewhere: the detail
            // is the only discoverable route to an existing profile's blocked
            // apps, which is what App Review could not find in 1.0 (35).
            .navigationDestination(item: $detail) { ref in
                if let profile = store.profiles.first(where: { $0.objectID == ref.objectID }) {
                    ProfileDetailView(
                        profile: profile,
                        onDeleteConfirmed: { deleteProfile(ref) },
                        onGoToSession: {
                            NotificationCenter.default.post(name: .zenlyOpenFocus, object: nil)
                            dismiss()
                        }
                    )
                } else {
                    // Deleted while pushed — render nothing rather than fault on
                    // a managed object that is on its way out.
                    Color.clear
                }
            }
            .sheet(isPresented: $showNewProfile) {
                ProfileEditView(profile: nil, draft: ProfileDraft())
            }
            // `sheet(isPresented:)` rather than `sheet(item:)`: `FocusProfile`
            // is an `NSManagedObject` whose `id` is optional, so it is not
            // `Identifiable` and cannot be the item.
            .sheet(isPresented: Binding(get: { pendingDelete != nil },
                                        set: { if !$0 { pendingDelete = nil } })) {
                if let profile = pendingDelete {
                    DeleteProfileSheet(
                        name: profile.name ?? "this profile",
                        sessionCount: analytics.sessionCount(profileName: profile.name ?? ""),
                        onDelete: {
                            pendingDelete = nil
                            Haptics.success()
                            store.delete(profile)
                        },
                        onKeep: { pendingDelete = nil }
                    )
                }
            }
            // Something below decided the user belongs on the Focus tab — a
            // session just started from the profile editor, or "Go to session"
            // was tapped. Get out of the way: a running session lives on that
            // tab, and this sheet sits over the top of it.
            .onReceive(NotificationCenter.default.publisher(for: .zenlyOpenFocus)) { _ in
                dismiss()
            }
        }
    }

    // MARK: - Way out

    /// A sheet is dismissed by dragging it down, and that is the only way out of
    /// this one — nothing on screen said so. The same shape as screen 20b's
    /// "‹ Profiles", pointing back where this was opened from.
    ///
    /// Outside the List rather than a row in it, so it stays put instead of
    /// scrolling away with the profiles.
    private var backBar: some View {
        HStack {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Settings")
                        .font(ZTheme.Font.body(15))
                }
                .foregroundStyle(ZTheme.Palette.brandBright)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profiles-back")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - List

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Profiles")
                    .font(ZTheme.Font.display(24, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                if store.profiles.count > 1 {
                    Button {
                        withAnimation { editMode = editMode.isEditing ? .inactive : .active }
                    } label: {
                        Text(editMode.isEditing ? "Done" : "Reorder")
                            .font(ZTheme.Font.body(15))
                            .foregroundStyle(ZTheme.Palette.brandBright)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Each profile blocks its own set of apps and remembers its default length.")
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .padding(.top, 18)
        .padding(.bottom, 14)
        .quietRow()
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(Array(store.profiles.enumerated()), id: \.element.objectID) { index, profile in
            VStack(spacing: 0) {
                ProfileRow(
                    profile: profile,
                    isRunning: isRunning(profile),
                    isBlocked: blockedDelete == profile.objectID,
                    remaining: session.remainingSeconds,
                    onGoToSession: {
                        NotificationCenter.default.post(name: .zenlyOpenFocus, object: nil)
                        dismiss()
                    }
                )
                .contentShape(Rectangle())
                // The row draws a chevron, so the tap must navigate. Switching
                // the running profile happens on the Focus screen's row; this
                // list is for managing them, and its chevron promises 20b.
                .onTapGesture {
                    guard !editMode.isEditing else { return }
                    Haptics.light()
                    detail = ProfileRef(objectID: profile.objectID)
                }

                // The comp rules between rows, not under the last one.
                if index < store.profiles.count - 1 {
                    Rectangle()
                        .fill(ZTheme.Palette.glassStroke)
                        .frame(height: 1)
                }
            }
            .quietRow()
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { requestDelete(profile) } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button { detail = ProfileRef(objectID: profile.objectID) } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(ZTheme.Palette.tone)
            }
        }
        .onMove { store.move(fromOffsets: $0, toOffset: $1) }
    }

    private var newProfileButton: some View {
        Button { showNewProfile = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                Text("New profile")
                    .font(ZTheme.Font.body(15))
            }
            .foregroundStyle(ZTheme.Palette.tone)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new-profile")
        .quietRow()
    }

    // MARK: - Deleting

    /// Delete confirmed on screen 20b. The detail has already popped itself; the
    /// object is removed only once that animation is over, because tearing a
    /// managed object out from under a view that is still on screen is how you
    /// get a fault on a deleted object.
    private func deleteProfile(_ ref: ProfileRef) {
        detail = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard let profile = store.profiles.first(where: { $0.objectID == ref.objectID })
            else { return }
            store.delete(profile)
        }
    }

    /// Screen 20 or screen 21, decided here.
    ///
    /// A running profile owns live shields and a countdown, so deleting it would
    /// leave enforcement pointing at a row that no longer exists. Rather than
    /// refusing in an alert — which is a dead end you have to dismiss — the row
    /// itself explains and offers the way out.
    private func requestDelete(_ profile: FocusProfile) {
        guard !isRunning(profile) else {
            Haptics.warning()
            withAnimation(ZTheme.Motion.smooth) { blockedDelete = profile.objectID }
            return
        }
        pendingDelete = profile
    }

    private func isRunning(_ profile: FocusProfile) -> Bool {
        session.phase == .focus && session.profileName == (profile.name ?? "")
    }
}

// MARK: - A row

private struct ProfileRow: View {
    let profile: FocusProfile
    let isRunning: Bool
    /// True once a delete was attempted on a running profile — comp 21.
    let isBlocked: Bool
    let remaining: Int
    var onGoToSession: () -> Void

    private var accent: Color { ZTheme.tone(forHex: profile.accentHex) }

    var body: some View {
        VStack(spacing: 0) {
            line
            if isBlocked { blockedNote }
        }
        // Only the running profile gets a surface. Everything else is a row on
        // the page, which is what keeps the coloured one legible as "this one".
        .padding(.horizontal, isRunning ? 12 : 0)
        .padding(.vertical, isRunning ? 4 : 0)
        .background {
            if isRunning {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.16))
            }
        }
        .padding(.horizontal, isRunning ? -12 : 0)
    }

    private var line: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name ?? "Untitled")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(summary)
                    .font(ZTheme.Font.body(12))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }

            Spacer(minLength: 0)

            if isRunning {
                Text("ACTIVE")
                    .font(ZTheme.Font.body(11))
                    .tracking(1.76)                       // .16em at 11pt
                    .foregroundStyle(accent)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
            }
        }
        .padding(.vertical, 16)
    }

    /// Comp 21 — the refusal, said in place.
    private var blockedNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ZTheme.Palette.warn)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(profile.name ?? "This profile") can\u{2019}t be deleted while it\u{2019}s running.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Finish the session\u{2009}\u{2014}\u{2009}\(minutesLeft)\u{2009}\u{2014}\u{2009}or end it first, then try again.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: { Haptics.light(); onGoToSession() }) {
                    Text("Go to session")
                        .font(ZTheme.Font.body(13, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.tone)
                        .padding(.top, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ZTheme.Palette.glassStroke)
                .frame(height: 1)
        }
        .padding(.bottom, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-delete-blocked")
    }

    /// "41 minutes" — whole minutes, rounded up so the last partial one still
    /// reads as time you have rather than none.
    private var minutesLeft: String {
        let minutes = max(1, Int(ceil(Double(remaining) / 60)))
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    private var summary: String {
        let focus = "\(profile.focusMinutes) min focus"
        let brk = profile.breakMinutes > 0 ? " · \(profile.breakMinutes) min break" : ""
        let strict = profile.isStrict ? " · strict" : ""
        return focus + brk + strict
    }
}

// MARK: - Screen 20 · the delete sheet

/// The comp's bottom card. Its whole job is the second sentence: the reason
/// people hesitate over a delete is not knowing what else goes with it, so the
/// sheet answers that before asking for the tap.
struct DeleteProfileSheet: View {
    let name: String
    let sessionCount: Int
    let onDelete: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Delete \u{201C}\(name)\u{201D}?")
                .font(ZTheme.Font.display(19, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(reassurance)
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            VStack(spacing: 4) {
                // Destructive, but not shouted: a neutral raise with the warn
                // tone on the label. The comp keeps red off this screen — the
                // sentence above has already said nothing irreversible happens
                // to the history, so alarm here would be overstating it.
                Button(action: { Haptics.warning(); onDelete() }) {
                    Text("Delete profile")
                        .font(ZTheme.Font.display(16, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.warn)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(ZTheme.Palette.glassFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(ZTheme.Palette.glassStroke, lineWidth: 1)
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("confirm-delete-profile")

                Button(action: { Haptics.light(); onKeep() }) {
                    Text("Keep it")
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("keep-profile")
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 26)
        .padding(.bottom, 20)
        // `border-top: 1px solid var(--line)` — the card's own edge. The sheet
        // background and the page behind it differ by three values out of 255,
        // so this hairline is what makes the card a card.
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ZTheme.Palette.glassStroke)
                .frame(height: 1)
        }
        .background(ZTheme.Palette.nightDeep)
        .presentationDetents([.height(268)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(ZTheme.Palette.nightDeep)
        .presentationCornerRadius(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("delete-profile-sheet")
    }

    /// The comp reads "its 12 sessions stay in your history". A profile that has
    /// never run has no sessions to reassure anyone about, and quoting "its 0
    /// sessions" would be the sentence drawing attention to its own template.
    private var reassurance: String {
        guard sessionCount > 0 else {
            return "The profile goes; nothing else changes\u{2014}your history and your streak aren\u{2019}t touched."
        }
        let sessions = sessionCount == 1 ? "session" : "sessions"
        return "The profile goes; its \(sessionCount) \(sessions) stay in your history and your streak isn\u{2019}t touched."
    }
}

// MARK: - Row chrome

extension View {
    /// Strip the system list-row chrome so a Quiet row sits directly on the
    /// page, ruled by its own hairline rather than boxed by the list's.
    func quietRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: QuietMetrics.gutter,
                                      bottom: 0, trailing: QuietMetrics.gutter))
    }

    /// Retained for the screens still on the earlier card layout.
    func plainRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: ZTheme.Spacing.lg,
                                      bottom: 6, trailing: ZTheme.Spacing.lg))
    }
}
