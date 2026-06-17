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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authorization)
                .environment(profiles)
                .environment(schedules)
                .environment(session)
                .environment(suggestions)
                .environment(analytics)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.refresh() }
        }
    }
}
