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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
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
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                session.refresh()
                applyFocusFilterProfile()
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }

    /// Switch to the profile chosen by an active iOS Focus filter, if any.
    private func applyFocusFilterProfile() {
        guard let name = AppGroup.defaults.string(forKey: "focusFilterProfile"),
              let profile = profiles.profiles.first(where: { $0.name == name }) else { return }
        profiles.setActive(profile)
    }
}
