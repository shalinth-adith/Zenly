//
//  SmartSuggestionService.swift
//  Zenly
//
//  Proposes recurring-schedule templates. Heuristic for now: if the user has
//  history, surface their most common focus hour; always offer a few sensible
//  templates. As analytics grow (Phase 3), this can get smarter.
//

import Foundation
import Observation

struct ScheduleSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let startHour: Int
    let endHour: Int
    let weekdays: Set<Int>
    let reason: String

    var draft: ScheduleDraft {
        ScheduleDraft(
            title: title,
            startHour: startHour,
            startMinute: 0,
            endHour: endHour,
            endMinute: 0,
            weekdays: weekdays
        )
    }
}

@Observable
@MainActor
final class SmartSuggestionService {
    private let history: SessionHistory

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
    }

    func suggestions() -> [ScheduleSuggestion] {
        var result: [ScheduleSuggestion] = []

        if let hour = mostCommonStartHour() {
            result.append(ScheduleSuggestion(
                title: "Your focus hour",
                startHour: hour,
                endHour: min(hour + 1, 23),
                weekdays: [2, 3, 4, 5, 6],
                reason: "You often focus around \(formatHour(hour))."
            ))
        }

        result.append(ScheduleSuggestion(
            title: "Deep Work",
            startHour: 9, endHour: 11,
            weekdays: [2, 3, 4, 5, 6],
            reason: "Mornings are great for hard tasks."
        ))
        result.append(ScheduleSuggestion(
            title: "Evening Study",
            startHour: 19, endHour: 21,
            weekdays: Set(1...7),
            reason: "Wind down with focused study."
        ))
        result.append(ScheduleSuggestion(
            title: "Digital Sunset",
            startHour: 22, endHour: 23,
            weekdays: Set(1...7),
            reason: "Avoid late-night scrolling."
        ))

        return result
    }

    private func mostCommonStartHour() -> Int? {
        let calendar = Calendar.current
        let hours = history.completedFocusSessions().compactMap { session in
            session.startedAt.map { calendar.component(.hour, from: $0) }
        }
        guard !hours.isEmpty else { return nil }

        let counts = Dictionary(grouping: hours, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    private func formatHour(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
