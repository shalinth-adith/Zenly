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
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The name shown in the Focus greeting ("Good evening, <name>"). Empty by
    /// default → a plain greeting; the user types their own name here.
    @AppStorage("userDisplayName", store: AppGroup.defaults) private var userName = ""

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3
    @AppStorage("streakGoal", store: AppGroup.defaults) private var streakGoal = 7
    @AppStorage(ShieldMessage.storageKey, store: AppGroup.defaults) private var shieldMessage = ""
    @AppStorage("breakReminderEnabled", store: AppGroup.defaults) private var reminderEnabled = false
    @AppStorage("breakReminderHour", store: AppGroup.defaults) private var reminderHour = 15
    @AppStorage("breakReminderMinute", store: AppGroup.defaults) private var reminderMinute = 0

    /// A source the user picked but hasn't confirmed switching to yet.
    @State private var showProfiles = false

    /// Drives the keyboard's Done button for the multiline shield-message field.
    @FocusState private var shieldFieldFocused: Bool

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
                    youSection
                    permissionSection
                    goalSection
                    shieldSection
                    breakReminderSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .tint(ZTheme.Palette.textPrimary)
                // Drag the form downward to dismiss. Independent of any toolbar,
                // so it works even where the keyboard accessory does not render.
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            // The shield-message field uses `axis: .vertical`, where Return
            // inserts a newline instead of submitting — so the keyboard needs an
            // explicit way out. Three independent paths, because a keyboard
            // accessory attached to a subview inside the ZStack does not
            // reliably render:
            //   1. this Done item, now hung off the NavigationStack's content root
            //   2. interactive scroll-to-dismiss (above)
            //   3. tapping the Done row in the section footer (see shieldSection)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { shieldFieldFocused = false }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showProfiles) { ProfilesView() }
            .onChange(of: reminderEnabled) { _, _ in updateReminder() }
            .onChange(of: reminderHour) { _, _ in updateReminder() }
            .onChange(of: reminderMinute) { _, _ in updateReminder() }
        }
    }

    /// Label + text field. Side-by-side normally; stacked at accessibility text
    /// sizes, where an `HStack` leaves neither child enough width and the field
    /// draws on top of the wrapped label.
    private var nameRow: some View {
        let field = TextField("Add your name", text: $userName)
            .foregroundStyle(ZTheme.Palette.text(0.7))
            .submitLabel(.done)

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your name")
                    field.multilineTextAlignment(.leading)
                }
                .padding(.vertical, 2)
            } else {
                HStack {
                    Text("Your name")
                    Spacer()
                    field.multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private var youSection: some View {
        Section("You") {
            nameRow
            Button {
                showProfiles = true
            } label: {
                HStack {
                    Text("Focus profiles")
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Spacer()
                    Text("\(profiles.profiles.count)")
                        .foregroundStyle(ZTheme.Palette.text(0.5))
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.3))
                }
            }
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
            // `axis: .vertical` makes Return insert a newline instead of
            // submitting, so this field needs an explicit way out of the
            // keyboard — otherwise it can be opened and never dismissed.
            TextField("e.g. Future you will thank you.",
                      text: $shieldMessage, axis: .vertical)
                .lineLimit(1...3)
                .focused($shieldFieldFocused)

            // Always-rendered escape hatch. The keyboard accessory can fail to
            // appear depending on how SwiftUI resolves the toolbar; an ordinary
            // row in the section cannot.
            if shieldFieldFocused {
                Button {
                    shieldFieldFocused = false
                } label: {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(ZTheme.Font.body(15, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.brandBright)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done editing shield message")
            }
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
            NotificationService.shared.scheduleDailyReminder(
                hour: reminderHour, minute: reminderMinute,
                focusedToday: SessionHistory().todayFocusMinutes() > 0)
        } else {
            NotificationService.shared.cancelDailyBreakReminder()
        }
    }
}
