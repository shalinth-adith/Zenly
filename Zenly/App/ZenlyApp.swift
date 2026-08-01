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
    @State private var accountability = AccountabilityService()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register()
        // Install the notification delegate before anything schedules or
        // delivers — otherwise foreground notifications are silently dropped.
        NotificationService.shared.activate()
        #if DEBUG
        MainActor.assumeIsolated {
            DebugSeed.seedDemoHistoryIfRequested()
            DebugSeed.seedManyProfilesIfRequested()
            // Stored-property initializers run before this body, so `profiles`
            // has already fetched by the time the seed inserts anything. The
            // history seed doesn't care — Insights queries on demand — but the
            // profile list is held in memory and would simply not show them.
            profiles.fetch()
        }
        DebugSeed.primeShieldPreviewSession()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let subject = DebugSeed.blockScreenPreviewSubject {
                // Screen 03 — the block screen. iOS draws the real one and
                // Simulator cannot raise a shield, so this puts the extension's
                // own strings on screen.
                BlockScreenPreview(
                    subject: subject,
                    tone: ZTheme.tone(forHex: profiles.activeProfile?.accentHex))
            } else if let subject = DebugSeed.shieldPreviewSubject {
                // Screen 03 normally needs a Screen Time shield to have fired,
                // which Simulator will never allow. Standing it up as the root
                // under a launch argument is the only way to look at it while
                // building. This is the real view, not a mock of one.
                AppPausedView(subject: subject,
                              tone: ZTheme.tone(forHex: profiles.activeProfile?.accentHex),
                              remaining: "16:12",
                              onDismiss: {})
            } else {
                root
            }
            #else
            root
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            #if DEBUG
            // The shield preview is standing in for another process. Letting the
            // app's own foreground work run behind it would auto-start scheduled
            // sessions nobody asked for.
            if DebugSeed.shieldPreviewSubject != nil || DebugSeed.blockScreenPreviewSubject != nil { return }
            #endif
            switch phase {
            case .active:
                authorization.refresh()
                session.restoreIfNeeded()
                session.applyPendingControlRequest()
                session.refresh()
                applyFocusFilterProfile()
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

    private var root: some View {
        AppEntryView()
            .environment(authorization)
            .environment(profiles)
            .environment(schedules)
            .environment(session)
            .environment(suggestions)
            .environment(analytics)
            .environment(achievements)
            .environment(challenges)
            .environment(accountability)
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
