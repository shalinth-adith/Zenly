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

struct SchedulesView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(ProfileStore.self) private var profiles
    @Environment(AuthorizationService.self) private var authorization
    @State private var editing: EditTarget?
    @State private var pendingDelete: FocusSchedule?

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
            .sheet(item: $editing) { target in
                switch target {
                case .newSchedule:
                    ScheduleEditView(schedule: nil, draft: ScheduleDraft())
                case .existing(let schedule):
                    ScheduleEditView(schedule: schedule, draft: store.draft(from: schedule))
                case .newProfile:
                    ProfileEditView(profile: nil, draft: ProfileDraft())
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
                            onEdit: { editing = .existing(schedule) },
                            onDelete: { pendingDelete = schedule })
            }
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
        return schedule.title?.isEmpty == false ? schedule.title! : "Focus block"
    }
}

/// One flat schedule row: start-time column, title + "days · length", and the
/// enable toggle. Disabled rows dim, matching the comp's off row.
private struct ScheduleRow: View {
    @Environment(ScheduleStore.self) private var store
    @ObservedObject var schedule: FocusSchedule
    var tone: Color
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            // Tappable content → edit; the toggle stays independently tappable.
            Button(action: { Haptics.light(); onEdit() }) {
                HStack(alignment: .center, spacing: 18) {
                    timeColumn
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(ZTheme.Font.display(15, weight: .semibold))
                            .foregroundStyle(schedule.isEnabled
                                             ? ZTheme.Palette.textPrimary
                                             : ZTheme.Palette.text(0.55))
                        Text("\(store.weekdaySummary(schedule)) · \(store.durationText(for: schedule))")
                            .font(ZTheme.Font.body(12))
                            .foregroundStyle(schedule.isEnabled
                                             ? ZTheme.Palette.text(0.55)
                                             : ZTheme.Palette.text(0.30))
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
        .padding(.vertical, 16)
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var title: String {
        if let t = schedule.title, !t.isEmpty { return t }
        if let p = schedule.profileName, !p.isEmpty { return p }
        return "Focus block"
    }

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
