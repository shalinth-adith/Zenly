//
//  RootView.swift
//  Zenly
//
//  Tab bar hosting the main surface: Home (sessions), Insights, Profiles,
//  Schedules, and Settings.
//
//  Redesign: the native tab bar is kept (all five destinations) but dressed in
//  the dark glass + periwinkle aesthetic of the "calm focus universe" (Claude
//  Design spec, Zenly.dc.html). The custom 4-tab floating bar in the mockup is a
//  visual simplification — applying its look here preserves every feature.
//

import SwiftUI
import UIKit

struct RootView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(ZTheme.Palette.night.opacity(0.6))
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Focus", systemImage: "timer") }
            AnalyticsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            ProfilesView()
                .tabItem { Label("Profiles", systemImage: "person.crop.circle") }
            SchedulesView()
                .tabItem { Label("Schedules", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(ZTheme.Palette.brand)
        .preferredColorScheme(.dark)
    }
}
