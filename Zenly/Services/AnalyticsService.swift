//
//  AnalyticsService.swift
//  Zenly
//
//  Derives weekly stats, a productivity score, and the widget snapshot from
//  completed sessions (Core Data) + the distraction log (App Group).
//

import Foundation
import Observation
import WidgetKit

struct DayStat: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let focusMinutes: Int
    let attempts: Int
}

@Observable
@MainActor
final class AnalyticsService {
    private let history: SessionHistory

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
    }

    /// Focus minutes + distraction attempts for the last 7 days (oldest first).
    func weeklyStats() -> [DayStat] {
        let calendar = Calendar.current
        let sessions = history.completedFocusSessions()
        let attempts = DistractionLog.counts()
        let today = calendar.startOfDay(for: Date())

        let weekdayLabel = DateFormatter()
        weekdayLabel.dateFormat = "EEE"

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = sessions
                .filter { $0.startedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
                .reduce(0) { $0 + Int($1.completedMinutes) }
            return DayStat(
                date: day,
                label: weekdayLabel.string(from: day),
                focusMinutes: minutes,
                attempts: attempts[DistractionLog.dayKey(day)] ?? 0
            )
        }
    }

    /// 0–100 score: focus volume + consistency, minus distraction attempts.
    func productivityScore() -> Int {
        let stats = weeklyStats()
        let totalFocus = stats.reduce(0) { $0 + $1.focusMinutes }
        let totalAttempts = stats.reduce(0) { $0 + $1.attempts }
        let activeDays = stats.filter { $0.focusMinutes > 0 }.count

        let focusComponent = min(60.0, Double(totalFocus) / (7.0 * 60.0) * 60.0) // 60 min/day target
        let consistencyComponent = Double(activeDays) / 7.0 * 40.0
        let penalty = min(20.0, Double(totalAttempts))

        return max(0, min(100, Int(focusComponent + consistencyComponent - penalty)))
    }

    func streak() -> Int { history.currentStreak() }
    func todayMinutes() -> Int { history.todayFocusMinutes() }

    /// Refresh the widget snapshot and reload timelines.
    func updateSnapshot() {
        let snapshot = StatsSnapshot(
            streak: streak(),
            todayMinutes: todayMinutes(),
            todayAttempts: DistractionLog.today(),
            updatedAt: Date()
        )
        StatsStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
