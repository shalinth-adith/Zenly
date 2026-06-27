//
//  SettingsView.swift
//  Zenly
//
//  Screen Time permission status and daily break reminders (scheduled with a
//  UNCalendarNotificationTrigger). Preferences persist in the App Group.
//
//  Redesign: grouped glass settings over the aurora with the glowing toggle and
//  brand tint (Claude Design spec, Zenly.dc.html). Controls and logic unchanged.
//  (The mockup's account / "Zenly Plus" / sign-out card is intentionally omitted
//  — Zenly has no user accounts.)
//

import SwiftUI

struct SettingsView: View {
    @Environment(AuthorizationService.self) private var authorization
    @Environment(CalendarService.self) private var calendar
    @Environment(TaskService.self) private var tasks
    @Environment(MusicController.self) private var music

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3
    @AppStorage("streakGoal", store: AppGroup.defaults) private var streakGoal = 7
    @AppStorage(ShieldMessage.storageKey, store: AppGroup.defaults) private var shieldMessage = ""
    @AppStorage("breakReminderEnabled", store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage("breakReminderHour", store: AppGroup.defaults) private var reminderHour = 15
    @AppStorage("breakReminderMinute", store: AppGroup.defaults) private var reminderMinute = 0

    /// A source the user picked but hasn't confirmed switching to yet.
    @State private var pendingSource: MusicSource?

    /// Frosted row background that lets the section's rounded corners clip it.
    private var glassRow: some View {
        Rectangle()
            .fill(ZTheme.Palette.matte)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                Form {
                    permissionSection
                    goalSection
                    shieldSection
                    integrationsSection
                    musicSection
                    breakReminderSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .tint(ZTheme.Palette.brandBright)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    .foregroundStyle(ZTheme.Palette.teal)
            default:
                Button("Grant Screen Time Access") {
                    Task { await authorization.requestAuthorization() }
                }
            }
        }
        .listRowBackground(glassRow)
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
        .listRowBackground(glassRow)
    }

    private var goalSection: some View {
        Section {
            Stepper(value: $dailyGoalMinutes, in: 30...480, step: 30) {
                LabeledContent("Daily focus goal", value: "\(dailyGoalMinutes) min")
            }
            Stepper(value: $dailySessionsGoal, in: 1...12, step: 1) {
                LabeledContent("Daily sessions goal", value: "\(dailySessionsGoal)")
            }
            Stepper(value: $streakGoal, in: 3...60, step: 1) {
                LabeledContent("Streak goal", value: "\(streakGoal) days")
            }
        } header: {
            Text("Daily Goals")
        } footer: {
            Text("Your daily targets, shown as progress orbs on Insights.")
        }
        .listRowBackground(glassRow)
    }

    private var integrationsSection: some View {
        Section {
            if calendar.isAuthorized {
                Label("Calendar connected", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(ZTheme.Palette.teal)
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
                    .foregroundStyle(ZTheme.Palette.teal)
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
        .listRowBackground(glassRow)
    }

    private var musicSection: some View {
        Section {
            // Selecting a different source only stages it; the actual switch
            // happens after the user confirms, so platforms never change by accident.
            Picker("Source", selection: Binding(
                get: { music.source },
                set: { newValue in
                    if newValue != music.source { pendingSource = newValue }
                }
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
        .listRowBackground(glassRow)
        .confirmationDialog(
            "Switch music source?",
            isPresented: Binding(get: { pendingSource != nil },
                                 set: { if !$0 { pendingSource = nil } }),
            presenting: pendingSource
        ) { target in
            Button("Switch to \(target.title)") {
                music.source = target
                pendingSource = nil
            }
            Button("Cancel", role: .cancel) { pendingSource = nil }
        } message: { target in
            Text("Change your focus music to \(target.title)?")
        }
    }

    private var breakReminderSection: some View {
        Section {
            Toggle("Daily break reminder", isOn: $reminderEnabled)
                .toggleStyle(.zenly)
            if reminderEnabled {
                DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Break Reminders")
        } footer: {
            Text("A gentle daily nudge to step away and recharge.")
        }
        .listRowBackground(glassRow)
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Phase", value: "2 — Sessions & Scheduling")
        }
        .listRowBackground(glassRow)
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
