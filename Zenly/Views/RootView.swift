//
//  RootView.swift
//  Zenly
//
//  Tab bar hosting the main surface: Focus (Home), Insights, Profiles,
//  Schedules, and Settings.
//
//  We use the NATIVE TabView tab bar rather than a hand-built one. On iOS 26 the
//  system bar renders in real Liquid Glass automatically — with the adaptive
//  luminosity, scroll-edge vibrancy and morphing selection indicator that a
//  custom `.glassEffect` shape on a dark background can't reproduce. Using the
//  system control (and only it) is also what removed the earlier doubled bar:
//  there's exactly one bar, owned by TabView.
//

import SwiftUI

extension Notification.Name {
    /// Posted by screens that want to land the user on the Focus tab (e.g. the
    /// Insights first-run "Begin your first focus" call).
    static let zenlyOpenFocus = Notification.Name("zenlyOpenFocus")
}

struct RootView: View {
    @Environment(ProfileStore.self) private var profiles
    @State private var selection = 0

    /// The single accent — the active profile's tone drives the selected tab.
    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        // Four tabs, matching the Quiet comp: Focus · Insights · Schedule ·
        // Settings. Profiles are switched from the row on the Focus screen and
        // managed from Settings, so they're no longer a tab.
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Focus", systemImage: "circle.circle") }
                .tag(0)
            AnalyticsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(1)
            SchedulesView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "sun.max") }
                .tag(3)
        }
        .tint(tone)
        .onReceive(NotificationCenter.default.publisher(for: .zenlyOpenFocus)) { _ in
            selection = 0
        }
    }
}
