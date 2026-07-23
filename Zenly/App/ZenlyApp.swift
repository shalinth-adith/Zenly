//
//  ZenlyApp.swift
//  Zenly
//
//  Composition root. Creates the shared @Observable controllers once and
//  injects them into the environment. Refreshes the active session's countdown
//  whenever the app returns to the foreground (drift-free resync).
//

import SwiftUI

@main
struct ZenlyApp: App {
    @State private var authorization = AuthorizationService()
    @State private var profiles = ProfileStore()
    @State private var schedules = ScheduleStore()
    @State private var session = FocusSessionController()
    @State private var suggestions = SmartSuggestionService()
    @State private var analytics = AnalyticsService()
    @State private var achievements = AchievementService()
    @State private var challenges = ChallengeService()
    @State private var ambient = AmbientSoundService()
    @State private var accountability = AccountabilityService()
    @State private var calendar = CalendarService()
    @State private var taskList = TaskService()
    @State private var music = MusicController()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register()
        // Install the notification delegate before anything schedules or
        // delivers — otherwise foreground notifications are silently dropped.
        NotificationService.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .environment(authorization)
                .environment(profiles)
                .environment(schedules)
                .environment(session)
                .environment(suggestions)
                .environment(analytics)
                .environment(achievements)
                .environment(challenges)
                .environment(ambient)
                .environment(accountability)
                .environment(calendar)
                .environment(taskList)
                .environment(music)
                .onOpenURL { url in music.handleSpotifyCallback(url) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                authorization.refresh()
                session.restoreIfNeeded()
                session.refresh()
                applyFocusFilterProfile()
                music.reconnectSpotifyIfNeeded()
                startPendingFocusIfNeeded()
                ScheduleAutoStart.run(schedules: schedules, session: session, profiles: profiles)
                ScheduleCountdown.run(schedules: schedules, session: session, profiles: profiles)
                rescheduleDailyReminder()
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }

    /// Start a session requested from outside the app (App Intent / Control
    /// Center / Siri), using the active profile.
    private func startPendingFocusIfNeeded() {
        guard FocusLaunchRequest.consume(),
              session.phase == .idle,
              let profile = profiles.activeProfile else { return }
        session.startFocus(
            profileName: profile.name ?? "Focus",
            accentHex: profile.accentHex ?? "1A3FA8",
            focusMinutes: Int(profile.focusMinutes),
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            blockAll: profile.blockAllApps,
            allowedWebDomains: WebDomainList.parse(profile.allowedWebDomains ?? ""),
            block: profiles.block(for: profile),
            allow: profiles.allow(for: profile)
        )
    }

    /// Re-arm the smart daily reminder for today's state (focused → break nudge,
    /// not yet → start-focus nudge). No-op when the reminder is disabled.
    private func rescheduleDailyReminder() {
        let defaults = AppGroup.defaults
        guard defaults.bool(forKey: "breakReminderEnabled") else {
            NotificationService.shared.cancelDailyBreakReminder()
            return
        }
        let hour = defaults.object(forKey: "breakReminderHour") as? Int ?? 15
        let minute = defaults.object(forKey: "breakReminderMinute") as? Int ?? 0
        NotificationService.shared.scheduleDailyReminder(
            hour: hour, minute: minute,
            focusedToday: session.todayFocusMinutes() > 0)
    }

    /// Switch to the profile chosen by an active iOS Focus filter, if any.
    private func applyFocusFilterProfile() {
        guard let name = AppGroup.defaults.string(forKey: "focusFilterProfile"),
              let profile = profiles.profiles.first(where: { $0.name == name }) else { return }
        profiles.setActive(profile)
    }
}
