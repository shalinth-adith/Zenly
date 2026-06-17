//
//  AnalyticsView.swift
//  Zenly
//
//  Weekly insights: productivity score, focus-minutes chart, distraction-attempt
//  chart (Swift Charts), and an embedded DeviceActivityReport for app usage.
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @Environment(AnalyticsService.self) private var analytics

    @State private var stats: [DayStat] = []
    @State private var score = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scoreCard
                    focusChartCard
                    distractionChartCard
                    usageCard
                    NavigationLink { BadgesView() } label: {
                        navRow(title: "Badges", systemImage: "rosette", tint: .yellow)
                    }
                    NavigationLink { LeaderboardView() } label: {
                        navRow(title: "Accountability", systemImage: "person.2.fill", tint: .blue)
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
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
        VStack(spacing: 10) {
            Text("Productivity Score")
                .font(.headline)
            ZStack {
                Circle()
                    .stroke(.tint.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
            }
            .frame(width: 140, height: 140)
            Text("Last 7 days")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var focusChartCard: some View {
        card(title: "Focus minutes", subtitle: "\(totalFocus) min this week") {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Day", stat.label),
                    y: .value("Minutes", stat.focusMinutes)
                )
                .foregroundStyle(.tint)
                .cornerRadius(4)
            }
            .frame(height: 160)
        }
    }

    private var distractionChartCard: some View {
        card(title: "Distraction attempts", subtitle: "\(totalAttempts) this week") {
            Chart(stats) { stat in
                BarMark(
                    x: .value("Day", stat.label),
                    y: .value("Attempts", stat.attempts)
                )
                .foregroundStyle(.orange)
                .cornerRadius(4)
            }
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
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .tint(tint)
    }

    private func card<Content: View>(title: String, subtitle: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
