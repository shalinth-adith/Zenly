//
//  AppEntryView.swift
//  Zenly
//
//  Shows the animated splash on launch, then crossfades into the app
//  (onboarding or the tab bar).
//

import SwiftUI
import Combine

struct AppEntryView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootContainerView()

            // Invisible watcher: while the app is foregrounded, polls each enabled
            // schedule and auto-starts a focus session when its window opens.
            ScheduleAutoStartWatcher()

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

/// Foreground-only clock that fires the schedule auto-start check. Granularity is
/// 30s, so a window starts within ~30s of its time while the app is open; the
/// scene-phase `.active` handler in ZenlyApp covers the instant of foregrounding.
private struct ScheduleAutoStartWatcher: View {
    @Environment(ScheduleStore.self) private var schedules
    @Environment(FocusSessionController.self) private var session
    @Environment(ProfileStore.self) private var profiles

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onReceive(tick) { _ in
                ScheduleAutoStart.run(schedules: schedules, session: session, profiles: profiles)
            }
    }
}
