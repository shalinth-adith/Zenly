//
//  ProfileDetailView.swift
//  Zenly
//
//  Quiet spec, screen 20b ("Profile · Gym") — what a profile row's chevron has
//  always promised and never delivered.
//
//  Until now the Profiles list drew a `chevron.right` on every row and wired the
//  tap to `setActive`, which changes nothing visible on that screen. The editor
//  was reachable only by a trailing swipe, so there was no discoverable way to
//  choose which apps an existing profile blocks. App Review found exactly that
//  ("the features were unresponsive, preventing us from selecting a specific app
//  to block") and rejected 1.0 (35) for it. This screen is the destination.
//
//  The comp: a "‹ Profiles" back and an "Edit" in the tone, the name at 24pt,
//  an in-session pill when it is running, a three-column stat strip ruled top
//  and bottom, then the two things a profile actually is — what it blocks and
//  when it starts — and a destructive "Delete profile" at the end.
//
//  Deleting is the pair already built for the list: screen 20's bottom sheet
//  when the profile is idle, screen 21's in-place refusal when it is running.
//

import CoreData
import FamilyControls
import SwiftUI

struct ProfileDetailView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(ScheduleStore.self) private var schedules
    @Environment(AnalyticsService.self) private var analytics
    @Environment(FocusSessionController.self) private var session
    @Environment(\.dismiss) private var dismiss

    let profile: FocusProfile
    /// The list owns the delete: this screen pops first, then the parent removes
    /// the object. Deleting from here would leave the view rendering a managed
    /// object that no longer exists for the length of the pop animation.
    var onDeleteConfirmed: () -> Void
    /// "Go to session" from the running-profile refusal (screen 21's way out).
    var onGoToSession: () -> Void

    @State private var showEditor = false
    @State private var showDelete = false
    /// True once a delete was attempted on a running profile — the refusal is a
    /// state of the screen, not an alert to dismiss.
    @State private var deleteBlocked = false

    private var tone: Color { ZTheme.tone(forHex: profile.accentHex) }
    private var name: String { profile.name ?? "Untitled" }
    private var isRunning: Bool {
        session.phase == .focus && session.profileName == (profile.name ?? "")
    }

    var body: some View {
        ZStack {
            ZTheme.Palette.night.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        title
                        statStrip
                        blockedSection
                        scheduleSection
                        deleteSection
                    }
                    .padding(.horizontal, QuietMetrics.gutter)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showEditor) {
            EditProfileSheet(profile: profile)
        }
        .sheet(isPresented: $showDelete) {
            DeleteProfileSheet(
                name: name,
                sessionCount: analytics.sessionCount(profileName: name),
                onDelete: {
                    showDelete = false
                    Haptics.success()
                    // Pop first — see `onDeleteConfirmed`.
                    dismiss()
                    onDeleteConfirmed()
                },
                onKeep: { showDelete = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Profiles")
                        .font(ZTheme.Font.body(15))
                }
                .foregroundStyle(tone)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-detail-back")

            Spacer(minLength: 0)

            Button {
                Haptics.light()
                showEditor = true
            } label: {
                Text("Edit")
                    .font(ZTheme.Font.body(15, weight: .semibold))
                    .foregroundStyle(tone)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-detail-edit")
        }
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - Title + in-session pill

    private var title: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(name)
                .font(ZTheme.Font.display(24, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)

            if isRunning {
                HStack(spacing: 8) {
                    Circle()
                        .fill(tone)
                        .frame(width: 6, height: 6)
                    Text("In session · \(minutesLeft) left")
                        .font(ZTheme.Font.body(12))
                        .tracking(1.2)                       // .1em at 12pt
                        .textCase(.uppercase)
                        .foregroundStyle(tone)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(tone.opacity(0.16)))
                .padding(.top, 8)
            }
        }
    }

    /// "41 minutes" — whole minutes, rounded up so the last partial one still
    /// reads as time you have rather than none.
    private var minutesLeft: String {
        let minutes = max(1, Int(ceil(Double(session.remainingSeconds) / 60)))
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }

    // MARK: - Stat strip

    private var statStrip: some View {
        HStack(spacing: 0) {
            stat("\(profile.focusMinutes) min", "Focus")
            stat(profile.breakMinutes > 0 ? "\(profile.breakMinutes) min" : "None", "Break")
            stat("\(analytics.sessionCount(profileName: name))", "Sessions")
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) { QuietHairline() }
        .overlay(alignment: .bottom) { QuietHairline() }
        .padding(.top, 26)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(ZTheme.Font.numeral(19, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            Text(label)
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Blocked apps

    private var block: FamilyActivitySelection { store.block(for: profile) }
    private var allow: FamilyActivitySelection { store.allow(for: profile) }
    private var allowedSites: [String] {
        WebDomainList.parse(profile.allowedWebDomains ?? "")
    }

    @ViewBuilder
    private var blockedSection: some View {
        QuietFieldLabel(text: "Blocked apps", topPadding: QuietMetrics.sectionGap)

        if profile.blockAllApps {
            plainRow("Every app", trailing: "except your allowed ones")
        } else if block.applicationTokens.isEmpty
                    && block.categoryTokens.isEmpty
                    && block.webDomainTokens.isEmpty {
            // The state that got the app rejected, said plainly, with the way
            // out named — "Edit" is the button at the top of this screen.
            QuietHelper(text: "Nothing is blocked yet. Tap Edit to choose the apps this profile holds back.")
                .padding(.bottom, 4)
        } else {
            // `ApplicationToken` is opaque — Screen Time never tells an app which
            // apps were picked. `Label(token)` is the one sanctioned way to draw
            // the real name and icon, and it only renders inside a process
            // holding the Family Controls entitlement.
            ForEach(Array(block.applicationTokens), id: \.self) { token in
                tokenRow { Label(token) }
            }
            ForEach(Array(block.categoryTokens), id: \.self) { token in
                tokenRow { Label(token) }
            }
            ForEach(Array(block.webDomainTokens), id: \.self) { token in
                tokenRow { Label(token) }
            }
        }

        if !allow.applicationTokens.isEmpty {
            QuietFieldLabel(text: profile.blockAllApps ? "Allowed apps" : "Always allowed",
                            topPadding: QuietMetrics.sectionGap)
            ForEach(Array(allow.applicationTokens), id: \.self) { token in
                tokenRow { Label(token) }
            }
        }

        if !allowedSites.isEmpty {
            QuietFieldLabel(text: "Allowed websites", topPadding: QuietMetrics.sectionGap)
            ForEach(allowedSites, id: \.self) { site in
                plainRow(site, trailing: nil)
            }
        }
    }

    /// A row carrying a Screen Time `Label`, tinted and ruled like the comp's.
    private func tokenRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .labelStyle(.titleAndIcon)
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 15)
            QuietHairline(color: ZTheme.Palette.glassFill)
        }
    }

    private func plainRow(_ title: String, trailing: String?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                Text(title)
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(ZTheme.Font.body(12))
                        .foregroundStyle(ZTheme.Palette.text(0.30))
                }
            }
            .padding(.vertical, 15)
            QuietHairline(color: ZTheme.Palette.glassFill)
        }
    }

    // MARK: - Schedule

    /// Every schedule pointed at this profile. They are linked by name, which is
    /// why renaming a profile in 20c carries its schedules along (see
    /// `EditProfileSheet.save`).
    private var profileSchedules: [FocusSchedule] {
        schedules.schedules.filter { ($0.profileName ?? "") == (profile.name ?? "") }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        QuietFieldLabel(text: "Schedule", topPadding: QuietMetrics.sectionGap)

        if profileSchedules.isEmpty {
            QuietHelper(text: "No schedule yet. Add one from the Schedule tab and this profile will start on its own.")
                .padding(.bottom, 4)
        } else {
            ForEach(profileSchedules, id: \.objectID) { schedule in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(schedules.weekdaySummary(schedule))
                            .font(ZTheme.Font.body(15))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                        Text(scheduleSubtitle(schedule))
                            .font(ZTheme.Font.body(12))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 15)
                    QuietHairline(color: ZTheme.Palette.glassFill)
                }
            }
        }
    }

    private func scheduleSubtitle(_ schedule: FocusSchedule) -> String {
        let start = Int(schedule.startHour) * 60 + Int(schedule.startMinute)
        let time = ScheduleEditView.timeText(start)
        return schedule.isEnabled
            ? "Starts on its own at \(time)"
            : "Paused — would start at \(time)"
    }

    // MARK: - Delete

    @ViewBuilder
    private var deleteSection: some View {
        Button {
            guard !isRunning else {
                Haptics.warning()
                withAnimation(ZTheme.Motion.smooth) { deleteBlocked = true }
                return
            }
            Haptics.light()
            showDelete = true
        } label: {
            Text("Delete profile")
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.warn)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.top, 18)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-detail-delete")

        // Screen 21's refusal, said in place rather than in an alert.
        if deleteBlocked {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ZTheme.Palette.warn)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(name) can\u{2019}t be deleted while it\u{2019}s running.")
                        .font(ZTheme.Font.body(13))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Finish the session\u{2009}\u{2014}\u{2009}\(minutesLeft)\u{2009}\u{2014}\u{2009}or end it first, then try again.")
                        .font(ZTheme.Font.body(13))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Haptics.light()
                        dismiss()
                        onGoToSession()
                    } label: {
                        Text("Go to session")
                            .font(ZTheme.Font.body(13, weight: .semibold))
                            .foregroundStyle(tone)
                            .padding(.top, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityIdentifier("profile-detail-delete-blocked")
        }
    }
}
