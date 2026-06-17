//
//  SettingsView.swift
//  Zenly
//
//  Screen Time permission status and daily break reminders (scheduled with a
//  UNCalendarNotificationTrigger). Preferences persist in the App Group.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthorizationService.self) private var authorization

    @AppStorage("breakReminderEnabled", store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage("breakReminderHour", store: AppGroup.defaults) private var reminderHour = 15
    @AppStorage("breakReminderMinute", store: AppGroup.defaults) private var reminderMinute = 0

    var body: some View {
        NavigationStack {
            Form {
                permissionSection
                breakReminderSection
                aboutSection
            }
            .navigationTitle("Settings")
            .onChange(of: reminderEnabled) { _, _ in updateReminder() }
            .onChange(of: reminderHour) { _, _ in updateReminder() }
            .onChange(of: reminderMinute) { _, _ in updateReminder() }
        }
    }

    private var permissionSection: some View {
        Section("Screen Time") {
            switch authorization.status {
            case .approved:
                Label("Access granted", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            default:
                Button("Grant Screen Time Access") {
                    Task { await authorization.requestAuthorization() }
                }
            }
        }
    }

    private var breakReminderSection: some View {
        Section {
            Toggle("Daily break reminder", isOn: $reminderEnabled)
            if reminderEnabled {
                DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Break Reminders")
        } footer: {
            Text("A gentle daily nudge to step away and recharge.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Phase", value: "2 — Sessions & Scheduling")
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = comps.hour ?? 15
                reminderMinute = comps.minute ?? 0
            }
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func updateReminder() {
        if reminderEnabled {
            NotificationService.shared.scheduleDailyBreakReminder(hour: reminderHour, minute: reminderMinute)
        } else {
            NotificationService.shared.cancelDailyBreakReminder()
        }
    }
}
