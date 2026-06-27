//
//  RootView.swift
//  Zenly
//
//  Tab bar hosting the main surface: Home (sessions), Insights, Profiles,
//  Schedules, and Settings.
//
//  Redesign (Zenly Matte spec): a custom floating-pill tab bar — a rounded
//  matteRaised capsule with a hairline border, the active tab's icon seated in a
//  tinted rounded-rect. The native UITabBar is hidden; the pill is hosted in a
//  bottom safe-area inset so each tab's scroll content stops above it. The
//  mockup shows four tabs as a visual simplification — we keep all five
//  destinations so no feature loses its navigation.
//

import SwiftUI

struct RootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            HomeView().tag(0)
            AnalyticsView().tag(1)
            ProfilesView().tag(2)
            SchedulesView().tag(3)
            SettingsView().tag(4)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            ZenlyTabBar(selection: $selection)
        }
        .tint(ZTheme.Palette.brand)
    }
}

/// The floating-pill tab bar from the Zenly Matte spec.
private struct ZenlyTabBar: View {
    @Binding var selection: Int

    private struct Item { let title: String; let icon: String }
    private let items: [Item] = [
        Item(title: "Focus",     icon: "timer"),
        Item(title: "Insights",  icon: "chart.bar.fill"),
        Item(title: "Profiles",  icon: "person.crop.circle"),
        Item(title: "Schedules", icon: "calendar"),
        Item(title: "Settings",  icon: "gearshape")
    ]

    private let activeIcon = Color(lightHex: "2257D6", darkHex: "9FC2FF")
    private let activeLabel = ZTheme.Palette.textPrimary
    private let activePill = Color(light: Color(hex: "2257D6").opacity(0.14),
                                   dark: Color(hex: "5C8DF5").opacity(0.20))

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let active = selection == i
                Button {
                    guard selection != i else { return }
                    selection = i
                    Haptics.light()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: items[i].icon)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 46, height: 30)
                            .background(active ? activePill : .clear,
                                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .foregroundStyle(active ? activeIcon : ZTheme.Palette.text(0.42))
                        Text(items[i].title)
                            .font(ZTheme.Font.body(10, weight: active ? .bold : .semibold))
                            .foregroundStyle(active ? activeLabel : ZTheme.Palette.text(0.42))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ZTheme.Palette.matteRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(ZTheme.Palette.matteBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }
}
