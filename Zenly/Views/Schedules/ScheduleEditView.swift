//
//  ScheduleEditView.swift
//  Zenly
//
//  Create or edit a recurring schedule: title, time window, weekdays,
//  blocklist/allowlist, and strict mode.
//

import SwiftUI
import FamilyControls

struct ScheduleEditView: View {
    @Environment(ScheduleStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let schedule: FocusSchedule?
    @State private var draft: ScheduleDraft
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showBlockPicker = false
    @State private var showAllowPicker = false
    @FocusState private var titleFocused: Bool

    private let weekdaySymbols: [(day: Int, label: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    init(schedule: FocusSchedule?, draft: ScheduleDraft) {
        self.schedule = schedule
        _draft = State(initialValue: draft)
        _startDate = State(initialValue: Self.date(hour: draft.startHour, minute: draft.startMinute))
        _endDate = State(initialValue: Self.date(hour: draft.endHour, minute: draft.endMinute))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                Form {
                Section {
                    TextField("Title (optional)", text: $draft.title)
                        .accessibilityIdentifier("schedule-title")
                        .focused($titleFocused)
                    DatePicker("Start", selection: $startDate, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endDate, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Leave the title blank and Zenly will name it for you.")
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(weekdaySymbols, id: \.day) { item in
                            let on = draft.weekdays.contains(item.day)
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .foregroundStyle(on ? .white : .primary)
                                .background(on ? Color.accentColor : ZTheme.Palette.glassFillRaised, in: Circle())
                                .onTapGesture {
                                    if on { draft.weekdays.remove(item.day) }
                                    else { draft.weekdays.insert(item.day) }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Days")
                } footer: {
                    if draft.weekdays.isEmpty {
                        Label("Pick at least one day to save.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(ZTheme.Palette.streak)
                    }
                }

                Section {
                    Toggle(isOn: $draft.blockAllApps) {
                        Label("Block all apps", systemImage: "nosign")
                    }
                    if !draft.blockAllApps {
                        Button { showBlockPicker = true } label: {
                            LabeledContent("Blocked apps & sites") { Text(countText(blockCount)) }
                        }
                    }
                    Button { showAllowPicker = true } label: {
                        LabeledContent(draft.blockAllApps ? "Allowed apps" : "Always allowed") {
                            Text(countText(draft.allow.applicationTokens.count))
                        }
                    }
                } header: {
                    Text("Blocking")
                } footer: {
                    Text(draft.blockAllApps
                         ? "Blocks every app and website during this schedule, except the allowed apps."
                         : "Blocks only the apps, categories, and sites you choose.")
                }

                Section {
                    Toggle(isOn: $draft.isStrict) {
                        Label("Strict mode", systemImage: "lock.shield")
                    }
                }
                }
                .scrollContentBackground(.hidden)
                .tint(ZTheme.Palette.brandBright)
            }
            .onAppear { if schedule == nil { titleFocused = true } }
            .navigationTitle(schedule == nil ? "New Schedule" : "Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .accessibilityIdentifier("schedule-save")
                        .disabled(!isValid)
                }
            }
            .familyActivityPicker(isPresented: $showBlockPicker, selection: $draft.block)
            .familyActivityPicker(isPresented: $showAllowPicker, selection: $draft.allow)
        }
    }

    private var blockCount: Int {
        draft.block.applicationTokens.count
            + draft.block.categoryTokens.count
            + draft.block.webDomainTokens.count
    }

    private var isValid: Bool {
        !draft.weekdays.isEmpty   // title is optional — defaulted on save
    }

    private func countText(_ count: Int) -> String {
        count == 0 ? "None" : "\(count)"
    }

    private func save() {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute], from: startDate)
        let end = calendar.dateComponents([.hour, .minute], from: endDate)
        draft.startHour = start.hour ?? 9
        draft.startMinute = start.minute ?? 0
        draft.endHour = end.hour ?? 17
        draft.endMinute = end.minute ?? 0

        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = "Focus block"
        }

        if let schedule {
            store.update(schedule, with: draft)
        } else {
            store.create(from: draft)
        }
        dismiss()
    }

    private static func date(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}
