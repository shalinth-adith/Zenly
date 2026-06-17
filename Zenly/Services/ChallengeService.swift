//
//  ChallengeService.swift
//  Zenly
//
//  Generates one daily challenge (deterministic from the date so it's stable
//  across launches) and tracks progress from real session data. Persisted in the
//  App Group. Fires a notification when completed.
//

import Foundation
import Observation

struct DailyChallenge: Codable {
    enum Kind: String, Codable {
        case minutes
        case sessions
        case longSession
    }

    let dateKey: String
    let kind: Kind
    let target: Int

    var title: String {
        switch kind {
        case .minutes: return "Focus for \(target) minutes today"
        case .sessions: return "Complete \(target) focus sessions"
        case .longSession: return "Complete a \(target)-minute session"
        }
    }

    var systemImage: String {
        switch kind {
        case .minutes: return "clock.badge.checkmark"
        case .sessions: return "checklist"
        case .longSession: return "timer"
        }
    }
}

@Observable
@MainActor
final class ChallengeService {
    private(set) var challenge: DailyChallenge
    private(set) var progress: Int = 0

    private let history: SessionHistory
    private let notifications = NotificationService.shared
    private let storageKey = "dailyChallenge"
    private let completedKey = "dailyChallengeCompletedDate"

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
        self.challenge = ChallengeService.loadOrMake()
        refresh()
    }

    var isComplete: Bool { progress >= challenge.target }
    var fraction: Double {
        challenge.target == 0 ? 0 : min(1, Double(progress) / Double(challenge.target))
    }

    /// Recompute today's challenge + progress; fire a completion notification once.
    func refresh() {
        challenge = ChallengeService.loadOrMake()
        progress = computeProgress(for: challenge)

        if isComplete {
            let today = ChallengeService.todayKey()
            if AppGroup.defaults.string(forKey: completedKey) != today {
                AppGroup.defaults.set(today, forKey: completedKey)
                notifications.notifyChallengeComplete(title: challenge.title)
            }
        }
    }

    // MARK: - Progress

    private func computeProgress(for challenge: DailyChallenge) -> Int {
        let calendar = Calendar.current
        let todaySessions = history.completedFocusSessions().filter {
            $0.startedAt.map { calendar.isDateInToday($0) } ?? false
        }
        switch challenge.kind {
        case .minutes:
            return todaySessions.reduce(0) { $0 + Int($1.completedMinutes) }
        case .sessions:
            return todaySessions.count
        case .longSession:
            return todaySessions.contains { Int($0.completedMinutes) >= challenge.target } ? challenge.target : 0
        }
    }

    // MARK: - Generation / persistence

    private static func loadOrMake() -> DailyChallenge {
        let today = todayKey()
        if let data = AppGroup.defaults.data(forKey: "dailyChallenge"),
           let existing = try? JSONDecoder().decode(DailyChallenge.self, from: data),
           existing.dateKey == today {
            return existing
        }
        let made = make(for: today)
        if let data = try? JSONEncoder().encode(made) {
            AppGroup.defaults.set(data, forKey: "dailyChallenge")
        }
        return made
    }

    private static func make(for dateKey: String) -> DailyChallenge {
        // Rotate deterministically by day-of-year so the challenge is stable.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        switch dayOfYear % 3 {
        case 0: return DailyChallenge(dateKey: dateKey, kind: .minutes, target: 60)
        case 1: return DailyChallenge(dateKey: dateKey, kind: .sessions, target: 3)
        default: return DailyChallenge(dateKey: dateKey, kind: .longSession, target: 25)
        }
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
