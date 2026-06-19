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
    @Environment(CalendarService.self) private var calendar
    @Environment(TaskService.self) private var tasks
    @Environment(MusicController.self) private var music

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage(ShieldMessage.storageKey, store: AppGroup.defaults) private var shieldMessage = ""
    @AppStorage(AIConfig.storageKey, store: AppGroup.defaults) private var anthropicKey = ""
    @AppStorage("breakReminderEnabled", store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage("breakReminderHour", store: AppGroup.defaults) private var reminderHour = 15
    @AppStorage("breakReminderMinute", store: AppGroup.defaults) private var reminderMinute = 0

    var body: some View {
        NavigationStack {
            Form {
                permissionSection
                goalSection
                shieldSection
                researchSection
                integrationsSection
                musicSection
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

    private var shieldSection: some View {
        Section {
            TextField("e.g. Future you will thank you.",
                      text: $shieldMessage, axis: .vertical)
                .lineLimit(1...3)
        } header: {
            Text("Shield message")
        } footer: {
            Text("Shown on the block screen when you open a distracting app during focus. Leave empty for the default.")
        }
    }

    private var researchSection: some View {
        Section {
            SecureField("sk-ant-…", text: $anthropicKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if anthropicKey.isEmpty {
                Label("Using the on-device classifier (no key).", systemImage: "iphone")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label("Claude classifier active", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Research browser AI")
        } footer: {
            Text("Optional Anthropic API key. With a key, the in-app Research browser uses Claude to judge unknown sites as knowledge or entertainment; without one it uses a built-in list. Only a site's domain is ever sent.")
        }
    }

    private var goalSection: some View {
        Section {
            Stepper(value: $dailyGoalMinutes, in: 30...480, step: 30) {
                LabeledContent("Daily focus goal", value: "\(dailyGoalMinutes) min")
            }
        } header: {
            Text("Goal")
        } footer: {
            Text("Your target focused minutes per day, shown on Home.")
        }
    }

    private var integrationsSection: some View {
        Section {
            if calendar.isAuthorized {
                Label("Calendar connected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if calendar.isDenied {
                Label("Calendar access denied — enable it in the Settings app.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button("Connect Calendar") {
                    Task { await calendar.requestAccess() }
                }
            }

            if tasks.remindersAuthorized {
                Label("Reminders connected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else if tasks.remindersDenied {
                Label("Reminders access denied — enable it in the Settings app.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button("Connect Reminders") {
                    Task { await tasks.requestRemindersAccess() }
                }
            }
        } header: {
            Text("Integrations")
        } footer: {
            Text("Calendar suggests focus during free time. Add a Zenly Focus Filter in Settings › Focus to switch profiles automatically.")
        }
    }

    private var musicSection: some View {
        Section {
            Picker("Source", selection: Binding(
                get: { music.source },
                set: { music.source = $0 }
            )) {
                ForEach(MusicSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            if music.source == .spotify {
                if music.spotifyConfigured {
                    Button("Connect Spotify") { music.connectSpotify() }
                } else {
                    Text("Add your Spotify Client ID in SpotifyConfig.swift to enable Spotify.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Music")
        } footer: {
            Text("Spotify requires the Spotify app and a Premium account.")
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
