//
//  GoalsView.swift
//  Zenly
//
//  Detail screen for the daily-goal "needs", opened by tapping the Daily Goals
//  card on Insights. Shows each goal as a large progress orb and lets the user
//  adjust its target inline. Matte theme.
//

import SwiftUI

/// A single daily-goal progress orb with a label + caption underneath. Shared by
/// the Insights summary card and this detail screen so both stay in sync.
struct GoalOrbView: View {
    var title: String
    var value: String
    var caption: String
    var progress: Double
    var tint: Color
    var diameter: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            FocusOrb(state: .active(progress: progress), diameter: diameter,
                     ringTint: tint, living: false, breathes: false) {
                Text(value)
                    .font(ZTheme.Font.numeral(diameter * 0.25, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) goal")
            .accessibilityValue("\(value) \(caption), \(Int(progress * 100)) percent")
            VStack(spacing: 1) {
                Text(title)
                    .font(ZTheme.Font.body(13, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(caption)
                    .font(ZTheme.Font.body(11))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct GoalsView: View {
    @Environment(FocusSessionController.self) private var session
    @Environment(AnalyticsService.self) private var analytics

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3
    @AppStorage("streakGoal", store: AppGroup.defaults) private var streakGoal = 7

    @State private var streak = 0
    @State private var todayMinutes = 0
    @State private var todaySessions = 0

    var body: some View {
        ZStack {
            ZenlyBackground()

            ScrollView {
                VStack(spacing: ZTheme.Spacing.lg) {
                    HStack(alignment: .top, spacing: ZTheme.Spacing.sm) {
                        GoalOrbView(title: "Focus", value: "\(todayMinutes)",
                                    caption: "of \(dailyGoalMinutes) min",
                                    progress: ratio(todayMinutes, dailyGoalMinutes),
                                    tint: ZTheme.Palette.brandGlow, diameter: 100)
                        GoalOrbView(title: "Sessions", value: "\(todaySessions)",
                                    caption: "of \(dailySessionsGoal)",
                                    progress: ratio(todaySessions, dailySessionsGoal),
                                    tint: ZTheme.Palette.teal, diameter: 100)
                        GoalOrbView(title: "Streak", value: "\(streak)",
                                    caption: "of \(streakGoal) days",
                                    progress: ratio(streak, streakGoal),
                                    tint: ZTheme.Palette.streak, diameter: 100)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: ZTheme.Spacing.md) {
                        ZenlySectionHeader(title: "Adjust targets")
                        targetStepper(title: "Focus minutes", value: $dailyGoalMinutes,
                                      range: 30...480, step: 30, unit: "min")
                        Divider().overlay(ZTheme.Palette.matteBorder)
                        targetStepper(title: "Sessions", value: $dailySessionsGoal,
                                      range: 1...12, step: 1, unit: "")
                        Divider().overlay(ZTheme.Palette.matteBorder)
                        targetStepper(title: "Streak", value: $streakGoal,
                                      range: 3...60, step: 1, unit: "days")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(radius: ZTheme.Radius.sheet, padding: 20)
                }
                .padding(.horizontal, ZTheme.Spacing.lg)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Daily Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(ZTheme.Palette.brandBright)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        streak = session.currentStreak()
        todayMinutes = session.todayFocusMinutes()
        todaySessions = analytics.todaySessions()
    }

    private func ratio(_ value: Int, _ goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(value) / Double(goal))
    }

    private func targetStepper(title: String, value: Binding<Int>,
                               range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                    .font(ZTheme.Font.body(15, weight: .medium))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Text(unit.isEmpty ? "\(value.wrappedValue)" : "\(value.wrappedValue) \(unit)")
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
            }
        }
    }
}
