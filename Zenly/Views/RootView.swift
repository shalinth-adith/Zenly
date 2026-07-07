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

struct RootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Focus", systemImage: "clock") }
                .tag(0)
            AnalyticsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(1)
            ProfilesView()
                .tabItem { Label("Profiles", systemImage: "person.crop.circle") }
                .tag(2)
            SchedulesView()
                .tabItem { Label("Schedules", systemImage: "calendar") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .tint(ZTheme.Palette.brandBright)
    }
}
