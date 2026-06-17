//
//  RootView.swift
//  Zenly
//
//  Tab bar hosting the Phase 2 surface: Home (sessions), Profiles, Schedules,
//  and Settings. Analytics arrives as a fifth tab in Phase 3.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "timer") }
            ProfilesView()
                .tabItem { Label("Profiles", systemImage: "person.crop.circle") }
            SchedulesView()
                .tabItem { Label("Schedules", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
