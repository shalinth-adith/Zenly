//
//  SchedulesView.swift
//  Zenly
//
//  Lists recurring focus schedules and offers smart suggestions to add new
//  ones. Toggle to enable/disable monitoring; swipe to edit or delete.
//
//  Redesign: glass schedule cards with the glowing toggle on the aurora (Claude
//  Design spec, Zenly.dc.html). Logic, suggestions, and swipe actions unchanged.
//

import SwiftUI

struct SchedulesView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(SmartSuggestionService.self) private var suggestions
    @Environment(AuthorizationService.self) private var authorization
    @State private var editing: EditTarget?
    @State private var pendingDelete: FocusSchedule?

    enum EditTarget: Identifiable {
        case new
        case existing(FocusSchedule)
        case suggestion(ScheduleDraft)

        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let schedule): return schedule.objectID.uriRepresentation().absoluteString
            case .suggestion(let draft): return "suggestion-\(draft.title)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                List {
                    ZenlyScreenTitle(title: "Schedule",
                                     subtitle: "Zenly starts these focus sessions for you automatically.")
                        .plainRow()
                        .padding(.bottom, 4)

                    permissionBanner
                    suggestionsSection
                    schedulesSection

                    DashedActionButton(title: "Add Schedule") { editing = .new }
                        .accessibilityIdentifier("add-schedule")
                        .plainRow()
                        .padding(.top, 4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { target in
                switch target {
                case .new:
                    ScheduleEditView(schedule: nil, draft: ScheduleDraft())
                case .existing(let schedule):
                    ScheduleEditView(schedule: schedule, draft: store.draft(from: schedule))
                case .suggestion(let draft):
                    ScheduleEditView(schedule: nil, draft: draft)
                }
            }
            .confirmationDialog(
                "Delete \u{201C}\(pendingDelete?.title ?? "this schedule")\u{201D}?",
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

    @ViewBuilder
    private var permissionBanner: some View {
        if !authorization.isAuthorized {
            VStack(alignment: .leading, spacing: 10) {
                Label("Screen Time access needed", systemImage: "hand.raised.fill")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("Schedules can only block apps automatically after you allow Screen Time access. Without it, a saved schedule won’t start on its own.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
                Button("Grant Access") {
                    Task {
                        await authorization.requestAuthorization()
                        if authorization.isAuthorized { store.rearmEnabled() }
                    }
                }
                .buttonStyle(.zenlyPrimary(tint: ZTheme.Palette.brand, height: 46))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            .overlay(
                RoundedRectangle(cornerRadius: ZTheme.Radius.card, style: .continuous)
                    .strokeBorder(ZTheme.Palette.streak.opacity(0.4), lineWidth: 1)
            )
            .plainRow()
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        let items = suggestions.suggestions()
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
                ZenlySectionHeader(title: "Suggested")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ZTheme.Spacing.sm) {
                        ForEach(items) { suggestion in
                            Button {
                                Haptics.light()
                                editing = .suggestion(suggestion.draft)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(suggestion.title)
                                        .font(ZTheme.Font.display(15, weight: .semibold))
                                        .foregroundStyle(ZTheme.Palette.textPrimary)
                                    Text(String(format: "%02d:00–%02d:00", suggestion.startHour, suggestion.endHour))
                                        .font(ZTheme.Font.body(12))
                                        .foregroundStyle(ZTheme.Palette.text(0.6))
                                    Text(suggestion.reason)
                                        .font(ZTheme.Font.body(11))
                                        .foregroundStyle(ZTheme.Palette.text(0.5))
                                        .lineLimit(2)
                                }
                                .frame(width: 160, alignment: .leading)
                                .glassCard(padding: ZTheme.Spacing.md)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .plainRow()
        }
    }

    @ViewBuilder
    private var schedulesSection: some View {
        if store.schedules.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 34))
                    .foregroundStyle(ZTheme.Palette.brandBright)
                Text("No schedules yet")
                    .font(ZTheme.Font.display(17, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("Zenly can start focus sessions automatically. Tap a suggestion above, or “Add Schedule” to block distractions during set hours.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: 22)
            .plainRow()
        } else {
            ForEach(store.schedules, id: \.objectID) { schedule in
                ScheduleRow(schedule: schedule)
                    .plainRow()
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDelete = schedule
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editing = .existing(schedule)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(ZTheme.Palette.brand)
                    }
            }
        }
    }
}

private struct ScheduleRow: View {
    @Environment(ScheduleStore.self) private var store
    let schedule: FocusSchedule

    // Mon-first week, matching how people read a schedule.
    private let pillDays: [(day: Int, label: String)] = [
        (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S"), (1, "S")
    ]

    var body: some View {
        let status = store.status(for: schedule)
        let isActive = { if case .active = status { return true } else { return false } }()
        let accent = isActive ? ZTheme.Palette.teal : ZTheme.Palette.brandGlow
        let days = ScheduleStore.weekdays(from: schedule.weekdaysMask)

        VStack(alignment: .leading, spacing: 12) {
            // Title + enable toggle
            HStack {
                Text(schedule.title?.isEmpty == false ? schedule.title! : "Untitled")
                    .font(ZTheme.Font.display(17, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { schedule.isEnabled },
                    set: { store.setEnabled(schedule, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.zenly)
            }

            // Time range + duration
            HStack(spacing: 8) {
                Text("\(time(schedule.startHour, schedule.startMinute)) → \(time(schedule.endHour, schedule.endMinute))")
                    .font(ZTheme.Font.numeral(16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ZTheme.Palette.text(0.9))
                Text("· \(store.durationText(for: schedule))")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
            }

            // Weekday pills
            HStack(spacing: 6) {
                ForEach(pillDays, id: \.day) { item in
                    let on = days.contains(item.day)
                    Text(item.label)
                        .font(ZTheme.Font.body(12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(on ? .white : ZTheme.Palette.text(0.4))
                        .background(Circle().fill(on ? accent.opacity(0.9) : ZTheme.Palette.matteRaised))
                }
            }

            // Blocking summary + live status
            HStack(spacing: 8) {
                Label(store.blockingSummary(for: schedule),
                      systemImage: schedule.blockAllApps ? "nosign" : "apps.iphone")
                    .font(ZTheme.Font.body(12, weight: .medium))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                Spacer()
                statusBadge(status)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: ZTheme.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZTheme.Radius.card, style: .continuous)
                .strokeBorder(isActive ? accent : .clear, lineWidth: 1.5)
                .shadow(color: isActive ? accent.opacity(0.4) : .clear, radius: 12)
        )
        .opacity(schedule.isEnabled ? 1 : 0.55)
    }

    @ViewBuilder
    private func statusBadge(_ status: ScheduleStore.ScheduleStatus) -> some View {
        switch status {
        case .active(let endsAt):
            HStack(spacing: 5) {
                Circle().fill(ZTheme.Palette.teal).frame(width: 7, height: 7)
                Text("Active now · ends \(hm(endsAt))")
            }
            .font(ZTheme.Font.body(12, weight: .semibold))
            .foregroundStyle(ZTheme.Palette.teal)
        case .upcoming(let at):
            Text("Next: \(relativeDay(at)) \(hm(at))")
                .font(ZTheme.Font.body(12, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.brandBright)
        case .off:
            Text("Off")
                .font(ZTheme.Font.body(12, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.text(0.4))
        case .idle:
            Text("No upcoming runs")
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.4))
        }
    }

    private func time(_ hour: Int16, _ minute: Int16) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func hm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}
