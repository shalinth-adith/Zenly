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

                    suggestionsSection
                    schedulesSection

                    DashedActionButton(title: "Add Schedule") { editing = .new }
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
            Text("No schedules yet. Add one below, or tap a suggestion to start.")
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
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

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(time(schedule.startHour, schedule.startMinute))
                    .font(ZTheme.Font.numeral(17, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            }
            .frame(width: 56)
            .overlay(alignment: .trailing) {
                Rectangle().fill(ZTheme.Palette.glassStroke).frame(width: 1, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.title?.isEmpty == false ? schedule.title! : "Untitled")
                    .font(ZTheme.Font.display(16, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("until \(time(schedule.endHour, schedule.endMinute)) · \(store.weekdaySummary(schedule))")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { schedule.isEnabled },
                set: { store.setEnabled(schedule, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.zenly)
        }
        .glassCard(padding: ZTheme.Spacing.md)
    }

    private func time(_ hour: Int16, _ minute: Int16) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
