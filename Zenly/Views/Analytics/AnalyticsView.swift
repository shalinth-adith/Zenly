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

    @State private var stats: [DayStat] = []
    @State private var score = 0

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
        }
    }

    private func refresh() {
        stats = analytics.weeklyStats()
        score = analytics.productivityScore()
        analytics.updateSnapshot()
    }

    private var totalFocus: Int { stats.reduce(0) { $0 + $1.focusMinutes } }
    private var totalAttempts: Int { stats.reduce(0) { $0 + $1.attempts } }

    // MARK: - Cards

    private var scoreCard: some View {
        HStack(spacing: ZTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(ZTheme.Palette.brandBright, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ZTheme.Palette.brandGlow.opacity(0.8), radius: 6)
                Text("\(score)")
                    .font(ZTheme.Font.numeral(30, weight: .bold))
                    .foregroundStyle(.white)
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
