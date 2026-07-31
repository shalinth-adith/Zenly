//
//  SchedulesView.swift
//  Zenly
//
//  Schedule — the Quiet comp exactly (Zenly Quiet.dc.html · screen 06): the
//  current week strip with today in the tone, flat schedule rows (start time ·
//  title · days + length · toggle) separated by hairlines, an "Add schedule"
//  action, and a PROFILES section whose "New profile" creates a focus profile
//  from here. No cards, no chrome.
//
//  Wiring: rows come from ScheduleStore (toggle = enable/disable monitoring;
//  tap = edit; long-press = edit/delete). "Add schedule" and "New profile"
//  open the existing edit sheets. A quiet inline notice asks for Screen Time
//  access when missing — without it schedules can't arm.
//

import SwiftUI
import CoreData

struct SchedulesView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(AuthorizationService.self) private var authorization
    @State private var editing: EditTarget?
    @State private var pendingDelete: FocusSchedule?
    /// The schedule just added — carries the comp's tone wash and NEW label
    /// until the user's eye has had a moment to land on it (screen 19).
    @State private var recentlyAdded: NSManagedObjectID?
    @State private var toast: ScheduleToast?
    /// Set when arriving here from "Put it on the schedule" on a new profile.
    @State private var prefilledProfileName: String?

    /// What the editor changed on the user's behalf, and how to put it back.
    struct ScheduleToast: Identifiable {
        let id = UUID()
        let message: String
        let undo: (() -> Void)?
    }

    enum EditTarget: Identifiable {
        case newSchedule
        case existing(FocusSchedule)
        case newProfile

        var id: String {
            switch self {
            case .newSchedule: return "new-schedule"
            case .existing(let schedule): return schedule.objectID.uriRepresentation().absoluteString
            case .newProfile: return "new-profile"
            }
        }
    }

    /// The single accent — the active profile's Quiet tone.
    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                VStack(spacing: 0) {
                    header
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            permissionNotice

                            sectionLabel(todayLabel)
                                .padding(.bottom, 8)
                            scheduleRows
                            addScheduleButton
                            hairline(strong: true)
                                .padding(.top, 6)

                            sectionLabel("Profiles")
                                .padding(.top, 20)
                                .padding(.bottom, 2)
                            newProfileButton
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { toastBar }
            .sheet(item: $editing, onDismiss: { prefilledProfileName = nil }) { target in
                switch target {
                case .newSchedule:
                    ScheduleEditView(schedule: nil,
                                     draft: ScheduleDraft(profileName: prefilledProfileName ?? ""),
                                     onSaved: handleSaved)
                case .existing(let schedule):
                    ScheduleEditView(schedule: schedule,
                                     draft: store.draft(from: schedule),
                                     onSaved: handleSaved)
                case .newProfile:
                    ProfileEditView(profile: nil,
                                    draft: ProfileDraft(),
                                    onScheduleRequested: scheduleNewProfile)
                }
            }
            .confirmationDialog(
                "Delete \u{201C}\(displayTitle(pendingDelete))\u{201D}?",
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
        }
    }

    // MARK: - Header (title + week strip)

    private var header: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Schedule")
                .font(ZTheme.Font.display(24, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            weekStrip
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }

    /// Mon-first current week: weekday letter over the day number. Today's
    /// number carries the tone; the weekend sits dimmer, like the comp.
    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let daysFromMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        let letters = ["M", "T", "W", "T", "F", "S", "S"]

        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: monday) ?? today
                let isToday = calendar.isDateInToday(day)
                let isWeekend = offset >= 5
                VStack(spacing: 7) {
                    Text(letters[offset])
                        .font(ZTheme.Font.body(11))
                        .foregroundStyle(ZTheme.Palette.text(0.30))
                    Text("\(calendar.component(.day, from: day))")
                        .font(ZTheme.Font.numeral(15))
                        .foregroundStyle(isToday ? tone
                                         : isWeekend ? ZTheme.Palette.text(0.30)
                                         : ZTheme.Palette.text(0.55))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted)
                                    + (isToday ? ", today" : ""))
            }
        }
    }

    private var todayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "Today · \(formatter.string(from: Date()))"
    }

    // MARK: - Schedule rows

    private var scheduleRows: some View {
        ForEach(Array(store.schedules.enumerated()), id: \.element.objectID) { index, schedule in
            VStack(spacing: 0) {
                if index > 0 { hairline() }
                ScheduleRow(schedule: schedule,
                            tone: tone,
                            detail: detail(for: schedule),
                            isNew: schedule.objectID == recentlyAdded,
                            onEdit: { editing = .existing(schedule) },
                            onDelete: { pendingDelete = schedule })
            }
        }
        .animation(ZTheme.Motion.smooth, value: recentlyAdded)
    }

    // MARK: - Just added (screen 19)

    /// The bar the comp shows after a schedule the editor had to adjust —
    /// what changed, and a way back. Only appears when something was changed
    /// on the user's behalf; a plain add just gets the NEW label on its row.
    @ViewBuilder
    private var toastBar: some View {
        if let toast {
            HStack(spacing: 14) {
                Text(toast.message)
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let undo = toast.undo {
                    Button("Undo") {
                        Haptics.light()
                        undo()
                        self.toast = nil
                        recentlyAdded = nil
                    }
                    .font(ZTheme.Font.display(14, weight: .semibold))
                    .foregroundStyle(tone)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(ZTheme.Palette.matteRaised)
                    .overlay(RoundedRectangle(cornerRadius: ZTheme.Radius.button,
                                              style: .continuous)
                        .strokeBorder(ZTheme.Palette.matteBorder, lineWidth: 1))
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func handleSaved(_ outcome: ScheduleSaveOutcome) {
        recentlyAdded = outcome.schedule.objectID
        if let note = outcome.note {
            toast = ScheduleToast(message: note, undo: outcome.undo)
        }
        let marked = outcome.schedule.objectID
        Task {
            try? await Task.sleep(for: .seconds(6))
            if recentlyAdded == marked { recentlyAdded = nil }
            toast = nil
        }
    }

    /// "Put it on the schedule" from a freshly created profile: the profile
    /// sheet dismisses itself, then the schedule editor opens prefilled. The
    /// pause lets the first sheet finish leaving before the second arrives.
    private func scheduleNewProfile(_ profile: FocusProfile) {
        prefilledProfileName = profile.name
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            editing = .newSchedule
        }
    }

    private var addScheduleButton: some View {
        VStack(spacing: 0) {
            if !store.schedules.isEmpty { hairline() }
            Button {
                Haptics.light()
                editing = .newSchedule
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add schedule")
                        .font(ZTheme.Font.display(15, weight: .semibold))
                }
                .foregroundStyle(tone)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("add-schedule")
        }
    }

    private var newProfileButton: some View {
        Button {
            Haptics.light()
            editing = .newProfile
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                Text("New profile")
                    .font(ZTheme.Font.display(15, weight: .semibold))
            }
            .foregroundStyle(tone)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("new-profile")
    }

    // MARK: - Permission notice (quiet, only when Screen Time is missing)

    @ViewBuilder
    private var permissionNotice: some View {
        if !authorization.isAuthorized {
            VStack(alignment: .leading, spacing: 6) {
                Text("Schedules need Screen Time access to start on their own.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                Button {
                    Task {
                        await authorization.requestAuthorization()
                        if authorization.isAuthorized { store.rearmEnabled() }
                    }
                } label: {
                    Text("Grant access")
                        .font(ZTheme.Font.display(14, weight: .semibold))
                        .foregroundStyle(tone)
                }
                .buttonStyle(.plain)
                hairline(strong: true)
                    .padding(.top, 14)
            }
            .padding(.bottom, 18)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ZTheme.Font.body(11))
            .tracking(1.8)
            .foregroundStyle(ZTheme.Palette.text(0.30))
    }

    private func hairline(strong: Bool = false) -> some View {
        Rectangle()
            .fill(strong ? ZTheme.Palette.glassStroke : ZTheme.Palette.glassStroke.opacity(0.6))
            .frame(height: 1)
    }

    private func displayTitle(_ schedule: FocusSchedule?) -> String {
        guard let schedule else { return "this schedule" }
        return ScheduleStore.displayName(for: schedule)
    }

    /// "Weekdays · 25 min" — which days it repeats, and how long a session runs.
    ///
    /// The comp's second number is the *session* length, which lives on the
    /// profile, not the width of the schedule's window. A schedule pointing at
    /// no profile we still have falls back to the window, which is the only
    /// length we can honestly state.
    private func detail(for schedule: FocusSchedule) -> String {
        let days = store.weekdaySummary(schedule)
        let profile = profiles.profiles.first { ($0.name ?? "") == (schedule.profileName ?? "") }
        guard let profile, profile.focusMinutes > 0 else {
            return "\(days) · \(store.durationText(for: schedule))"
        }
        return "\(days) · \(profile.focusMinutes) min"
    }
}

/// One flat schedule row: start-time column, title + "days · length", and the
/// enable toggle. Disabled rows dim, matching the comp's off row.
private struct ScheduleRow: View {
    @Environment(ScheduleStore.self) private var store
    @ObservedObject var schedule: FocusSchedule
    var tone: Color
    /// "Weekdays · 25 min", composed by the list (it holds the profiles).
    var detail: String
    /// Just added — wears the tone wash and the NEW label from the comp.
    var isNew: Bool = false
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        rowContent
            .padding(.vertical, 16)
            .padding(.horizontal, isNew ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: QuietMetrics.tileRadius, style: .continuous)
                    .fill(isNew ? tone.opacity(0.16) : .clear)
            )
            .padding(.horizontal, isNew ? -12 : 0)
            .contextMenu {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: 18) {
            // Tappable content → edit; the toggle stays independently tappable.
            Button(action: { Haptics.light(); onEdit() }) {
                HStack(alignment: .center, spacing: 18) {
                    timeColumn
                    // One line each: the comp's rows are a fixed two-line
                    // rhythm, and a long "Profile · Title" that wrapped would
                    // make one row taller than its neighbours.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(ZTheme.Font.display(15, weight: .semibold))
                            .foregroundStyle(schedule.isEnabled
                                             ? ZTheme.Palette.textPrimary
                                             : ZTheme.Palette.text(0.55))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        HStack(spacing: 7) {
                            // The comp puts "New" where our toggle lives, so it
                            // rides with the detail instead — the title stays
                            // readable at the moment you have just named it.
                            if isNew {
                                Text("NEW")
                                    .font(ZTheme.Font.body(11))
                                    .tracking(1.76)
                                    .foregroundStyle(tone)
                            }
                            Text(detail)
                                .font(ZTheme.Font.body(12))
                                .foregroundStyle(schedule.isEnabled
                                                 ? ZTheme.Palette.text(0.55)
                                                 : ZTheme.Palette.text(0.30))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // System toggle — reliable in scrolling content; tinted by the tone.
            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { store.setEnabled(schedule, $0) }
            ))
            .labelsHidden()
            .tint(tone)
            .accessibilityIdentifier("schedule-toggle")
            .accessibilityLabel("\(title) enabled")
        }
    }

    private var title: String { ScheduleStore.displayName(for: schedule) }

    /// "9:00" over "AM" — 12-hour start time, like the comp's time column.
    private var timeColumn: some View {
        let hour24 = Int(schedule.startHour)
        let minute = Int(schedule.startMinute)
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let meridiem = hour24 < 12 ? "AM" : "PM"
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(format: "%d:%02d", hour12, minute))
                .font(ZTheme.Font.numeral(15))
                .foregroundStyle(schedule.isEnabled
                                 ? ZTheme.Palette.textPrimary
                                 : ZTheme.Palette.text(0.55))
            Text(meridiem)
                .font(ZTheme.Font.body(11))
                .tracking(0.9)
                .foregroundStyle(ZTheme.Palette.text(0.30))
        }
        .frame(width: 58, alignment: .leading)
    }
}
