//
//  AnalyticsView.swift
//  Zenly
//
//  Weekly insights: productivity score, focus-minutes chart, distraction-attempt
//  chart (Swift Charts), and an embedded DeviceActivityReport for app usage.
//
//  Redesign: aurora backdrop + frosted glass cards with a glowing score ring
//  (Claude Design spec, Zenly.dc.html). Data and navigation unchanged.
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(AnalyticsService.self) private var analytics
    @Environment(FocusSessionController.self) private var session
    @Environment(ChallengeService.self) private var challenges
    @Environment(CalendarService.self) private var calendar

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3
    @AppStorage("streakGoal", store: AppGroup.defaults) private var streakGoal = 7

    @State private var stats: [DayStat] = []
    @State private var score = 0
    @State private var streak = 0
    @State private var todayMinutes = 0
    @State private var todaySessions = 0
    @State private var freeBlock: FreeBlock?
    @State private var showChallengeDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                ScrollView {
                    VStack(spacing: ZTheme.Spacing.md) {
                        Text("Insights")
                            .font(ZTheme.Font.display(32, weight: .bold))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        scoreCard
                        dailyGoalsCard
                        Button { showChallengeDetail = true } label: { challengeCard }
                            .buttonStyle(.plain)
                        if freeBlock != nil { freeTimeCard }
                        focusChartCard
                        distractionChartCard
                        usageCard
                        NavigationLink { HistoryView() } label: {
                            navRow(title: "History", systemImage: "clock.arrow.circlepath", tint: ZTheme.Palette.brand)
                        }
                        NavigationLink { BadgesView() } label: {
                            navRow(title: "Badges", systemImage: "rosette", tint: ZTheme.Palette.streakWarm)
                        }
                        NavigationLink { LeaderboardView() } label: {
                            navRow(title: "Accountability", systemImage: "person.2.fill", tint: ZTheme.Palette.teal)
                        }
                    }
                    .padding(.horizontal, ZTheme.Spacing.lg)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: refresh)
            .sheet(isPresented: $showChallengeDetail) { ChallengeDetailView() }
        }
    }

    private func refresh() {
        stats = analytics.weeklyStats()
        score = analytics.productivityScore()
        analytics.updateSnapshot()
        streak = session.currentStreak()
        todayMinutes = session.todayFocusMinutes()
        todaySessions = analytics.todaySessions()
        challenges.refresh()
        freeBlock = calendar.isAuthorized ? calendar.nextFreeBlock : nil
    }

    private var totalFocus: Int { stats.reduce(0) { $0 + $1.focusMinutes } }
    private var totalAttempts: Int { stats.reduce(0) { $0 + $1.attempts } }

    // MARK: - Cards

    private var scoreCard: some View {
        HStack(spacing: ZTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(ZTheme.Palette.glassStroke, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(ZTheme.Palette.brandBright, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ZTheme.Palette.brandGlow.opacity(0.8), radius: 6)
                Text("\(score)")
                    .font(ZTheme.Font.numeral(30, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 3) {
                Text("Productivity Score")
                    .font(ZTheme.Font.display(18, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("Last 7 days")
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            Spacer()
        }
        .glassCard(radius: ZTheme.Radius.sheet, padding: 20)
    }

    private var focusChartCard: some View {
        card(title: "Focus minutes", subtitle: "\(totalFocus) min this week") {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Day", stat.label),
                    y: .value("Minutes", stat.focusMinutes)
                )
                .foregroundStyle(
                    LinearGradient(colors: [ZTheme.Palette.violet, ZTheme.Palette.brand],
                                   startPoint: .top, endPoint: .bottom)
                )
                .cornerRadius(6)
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(ZTheme.Palette.text(0.4)) } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(ZTheme.Palette.text(0.4)) } }
            .frame(height: 160)
        }
    }

    private var distractionChartCard: some View {
        card(title: "Distractions blocked", subtitle: "\(totalAttempts) this week") {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Day", stat.label),
                    y: .value("Attempts", stat.attempts)
                )
                .foregroundStyle(ZTheme.Palette.teal.opacity(0.6))
                .cornerRadius(4)
            }
            .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(ZTheme.Palette.text(0.4)) } }
            .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(ZTheme.Palette.text(0.4)) } }
            .frame(height: 140)
        }
    }

    private var usageCard: some View {
        card(title: "App usage", subtitle: "Powered by Screen Time") {
            AppUsageReportView()
                .frame(height: 220)
        }
    }

    // Daily snapshot cards (relocated from the Focus tab so it stays a single,
    // calm screen). Read-only here — quick-start actions live on Focus.

    /// The daily-goal "needs" as a row of progress orbs (Focus / Sessions /
    /// Streak), each ring filling toward its configurable target. Reuses the
    /// FocusOrb design at a compact size.
    private var dailyGoalsCard: some View {
        NavigationLink {
            GoalsView()
        } label: {
            VStack(alignment: .leading, spacing: ZTheme.Spacing.md) {
                HStack {
                    Text("Daily Goals")
                        .font(ZTheme.Font.display(16, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.4))
                }
                HStack(alignment: .top, spacing: ZTheme.Spacing.sm) {
                    GoalOrbView(title: "Focus", value: "\(todayMinutes)",
                                caption: "of \(dailyGoalMinutes) min",
                                progress: ratio(todayMinutes, dailyGoalMinutes),
                                tint: ZTheme.Palette.brandGlow)
                    GoalOrbView(title: "Sessions", value: "\(todaySessions)",
                                caption: "of \(dailySessionsGoal)",
                                progress: ratio(todaySessions, dailySessionsGoal),
                                tint: ZTheme.Palette.teal)
                    GoalOrbView(title: "Streak", value: "\(streak)",
                                caption: "of \(streakGoal) days",
                                progress: ratio(streak, streakGoal),
                                tint: ZTheme.Palette.streak)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: ZTheme.Radius.sheet, padding: 20)
        }
        .buttonStyle(.plain)
    }

    private func ratio(_ value: Int, _ goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(value) / Double(goal))
    }

    private var challengeCard: some View {
        HStack(spacing: ZTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ZTheme.Palette.violet.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ZTheme.Palette.violet.opacity(0.4), lineWidth: 1))
                    .frame(width: 44, height: 44)
                Image(systemName: challenges.challenge.systemImage)
                    .foregroundStyle(ZTheme.Palette.lavenderSoft)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Challenge")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(challenges.challenge.title)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            Spacer()
            if challenges.isComplete {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(ZTheme.Palette.teal)
            } else {
                Text("\(challenges.progress)/\(challenges.challenge.target)")
                    .font(ZTheme.Font.display(13, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.lavenderSoft)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.text(0.3))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var freeTimeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Free time", systemImage: "calendar")
                .font(ZTheme.Font.display(15, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            if let block = freeBlock {
                Text("You're free until \(block.end.formatted(date: .omitted, time: .shortened)) — \(block.minutes) min.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func navRow(title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(ZTheme.Font.display(16, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .tint(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ZTheme.Palette.text(0.4))
        }
        .glassCard(padding: ZTheme.Spacing.lg)
    }

    private func card<Content: View>(title: String, subtitle: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(ZTheme.Font.display(16, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Text(subtitle)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: ZTheme.Radius.sheet, padding: 20)
    }
}
