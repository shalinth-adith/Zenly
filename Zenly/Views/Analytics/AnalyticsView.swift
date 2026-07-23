//
//  AnalyticsView.swift
//  Zenly
//
//  Insights — the Quiet comp exactly (Zenly Quiet.dc.html · screens 04 + 05):
//  a HISTORY section (weekly hours numeral, vs-last-week delta, a flat 7-bar
//  chart with today in the tone, recent session rows) and a GOALS section
//  (weekly focus + sessions hairline progress bars, current streak). No cards,
//  no chrome — flat rows separated by hairlines on the quiet surface.
//
//  First run (no sessions yet) shows the comp-05 empty state: a thin circle
//  with a tone dot and a "Begin your first focus" call that jumps to Focus.
//

import SwiftUI

struct AnalyticsView: View {
    @Environment(AnalyticsService.self) private var analytics
    @Environment(ProfileStore.self) private var profiles

    @AppStorage("dailyGoalMinutes", store: AppGroup.defaults) private var dailyGoalMinutes = 120
    @AppStorage("dailySessionsGoal", store: AppGroup.defaults) private var dailySessionsGoal = 3

    @State private var stats: [DayStat] = []
    @State private var recent: [FocusSession] = []
    @State private var previousWeekMinutes = 0
    @State private var weekSessions = 0
    @State private var streak = 0

    /// The single accent — the active profile's Quiet tone.
    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                if recent.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            title

                            sectionLabel("History")
                                .padding(.bottom, 14)
                            weeklyHours
                            barChart
                                .padding(.top, 40)
                            hairline(strong: true)
                                .padding(.top, 28)
                            sessionRows

                            sectionLabel("Goals")
                                .padding(.top, 34)
                                .padding(.bottom, 18)
                            goalRows
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: refresh)
        }
    }

    // MARK: - Data

    private func refresh() {
        stats = analytics.weeklyStats()
        recent = analytics.recentSessions(limit: 5)
        previousWeekMinutes = analytics.previousWeekMinutes()
        weekSessions = analytics.weekSessionCount()
        streak = analytics.streak()
        analytics.updateSnapshot()
    }

    private var weekMinutes: Int { stats.reduce(0) { $0 + $1.focusMinutes } }
    private var weekHours: Double { Double(weekMinutes) / 60 }
    private var weeklyGoalHours: Double { Double(dailyGoalMinutes * 7) / 60 }
    private var weeklySessionsGoal: Int { dailySessionsGoal * 7 }

    /// "+1.1 h vs last week" / "−0.4 h vs last week" / "Same as last week".
    private var deltaText: String {
        let delta = Double(weekMinutes - previousWeekMinutes) / 60
        if abs(delta) < 0.05 { return "Same as last week" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(String(format: "%.1f", abs(delta))) h vs last week"
    }

    // MARK: - Header

    private var title: some View {
        Text("Insights")
            .font(ZTheme.Font.display(24, weight: .semibold))
            .foregroundStyle(ZTheme.Palette.textPrimary)
            .padding(.bottom, 34)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(ZTheme.Font.body(11))
            .tracking(1.8)
            .foregroundStyle(ZTheme.Palette.text(0.30))
    }

    // MARK: - History

    private var weeklyHours: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", weekHours))
                    .font(ZTheme.Font.numeral(52, weight: .regular))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("hours this week")
                    .font(ZTheme.Font.body(16))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            Text(deltaText)
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: "%.1f", weekHours)) hours focused this week. \(deltaText)")
    }

    /// Flat 7-day bar chart — plain rounded bars on the raise fill, today's bar
    /// in the tone (the design's single highlight).
    private var barChart: some View {
        let maxMinutes = max(1, stats.map(\.focusMinutes).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                let isToday = index == stats.count - 1
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isToday ? tone : ZTheme.Palette.glassFill)
                        .frame(width: 20,
                               height: stat.focusMinutes == 0
                                   ? 4
                                   : max(8, CGFloat(stat.focusMinutes) / CGFloat(maxMinutes) * 100))
                    Text(String(stat.label.prefix(1)))
                        .font(ZTheme.Font.body(11))
                        .foregroundStyle(isToday ? ZTheme.Palette.textPrimary
                                                 : ZTheme.Palette.text(0.30))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stat.label): \(stat.focusMinutes) minutes")
            }
        }
        .frame(height: 134)
    }

    private var sessionRows: some View {
        ForEach(Array(recent.enumerated()), id: \.element.objectID) { index, session in
            VStack(spacing: 0) {
                if index > 0 { hairline() }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(dayLabel(session.startedAt)) · \(session.profileName ?? "Focus")")
                            .font(ZTheme.Font.body(15))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                        Text(session.wasCompleted ? "Completed" : "Ended early")
                            .font(ZTheme.Font.body(12))
                            .foregroundStyle(ZTheme.Palette.text(0.30))
                    }
                    Spacer()
                    Text("\(session.completedMinutes) min")
                        .font(ZTheme.Font.numeral(15))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                }
                .padding(.vertical, 14)
            }
        }
    }

    private func dayLabel(_ date: Date?) -> String {
        guard let date else { return "—" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Goals

    private var goalRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            goalRow(title: "Weekly focus",
                    value: "\(String(format: "%.1f", weekHours)) / \(trimmed(weeklyGoalHours)) h",
                    progress: weeklyGoalHours > 0 ? weekHours / weeklyGoalHours : 0,
                    fill: tone)
            hairline()
                .padding(.top, 20)
            goalRow(title: "Sessions",
                    value: "\(weekSessions) / \(weeklySessionsGoal)",
                    progress: weeklySessionsGoal > 0 ? Double(weekSessions) / Double(weeklySessionsGoal) : 0,
                    fill: ZTheme.Palette.text(0.30))
                .padding(.top, 18)
            hairline()
                .padding(.top, 20)
            HStack {
                Text("Current streak")
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Text("\(streak) day\(streak == 1 ? "" : "s")")
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            .padding(.vertical, 16)
        }
    }

    private func goalRow(title: String, value: String, progress: Double, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer()
                Text(value)
                    .font(ZTheme.Font.numeral(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ZTheme.Palette.glassFill)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fill)
                        .frame(width: max(0, min(1, progress)) * geo.size.width)
                }
            }
            .frame(height: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    /// "10" not "10.0" for whole-hour goals.
    private func trimmed(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(hours))
            : String(format: "%.1f", hours)
    }

    private func hairline(strong: Bool = false) -> some View {
        Rectangle()
            .fill(strong ? ZTheme.Palette.glassStroke : ZTheme.Palette.glassStroke.opacity(0.6))
            .frame(height: 1)
    }

    // MARK: - Empty state (comp 05 · first run)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            title
            Spacer()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(ZTheme.Palette.glassStroke, lineWidth: 2)
                        .frame(width: 108, height: 108)
                    Circle()
                        .fill(tone)
                        .frame(width: 6, height: 6)
                }
                VStack(spacing: 8) {
                    Text("Your focus story starts here")
                        .font(ZTheme.Font.display(19, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text("Finish your first session and this space fills in — hours focused, streaks, and the goals you set.")
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 270)
                }
                Button {
                    Haptics.light()
                    NotificationCenter.default.post(name: .zenlyOpenFocus, object: nil)
                } label: {
                    Text("Begin your first focus")
                        .font(ZTheme.Font.display(15, weight: .semibold))
                        .foregroundStyle(Color(hex: "0A0B0E"))
                        .padding(.horizontal, 30)
                        .frame(height: 50)
                        .background(tone, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
    }
}
