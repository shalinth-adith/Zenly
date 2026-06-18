//
//  SchedulesView.swift
//  Zenly
//
//  Lists recurring focus schedules and offers smart suggestions to add new
//  ones. Toggle to enable/disable monitoring; swipe to edit or delete.
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
            List {
                suggestionsSection
                schedulesSection
            }
            .navigationTitle("Schedules")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = .new } label: { Image(systemName: "plus") }
                }
            }
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

    private var suggestionsSection: some View {
        Section("Suggested") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(suggestions.suggestions()) { suggestion in
                        Button {
                            editing = .suggestion(suggestion.draft)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(String(format: "%02d:00–%02d:00", suggestion.startHour, suggestion.endHour))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 0))
        }
    }

    @ViewBuilder
    private var schedulesSection: some View {
        if store.schedules.isEmpty {
            Section {
                Text("No schedules yet. Add one above, or tap + to create your own.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section("Your schedules") {
                ForEach(store.schedules, id: \.objectID) { schedule in
                    ScheduleRow(schedule: schedule)
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
                            .tint(.indigo)
                        }
                }
            }
        }
    }
}

private struct ScheduleRow: View {
    @Environment(ScheduleStore.self) private var store
    let schedule: FocusSchedule

    var body: some View {
        Toggle(isOn: Binding(
            get: { schedule.isEnabled },
            set: { store.setEnabled(schedule, $0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(schedule.title?.isEmpty == false ? schedule.title! : "Untitled")
                    .font(.headline)
                Text("\(time(schedule.startHour, schedule.startMinute))–\(time(schedule.endHour, schedule.endMinute)) · \(store.weekdaySummary(schedule))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func time(_ hour: Int16, _ minute: Int16) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}
