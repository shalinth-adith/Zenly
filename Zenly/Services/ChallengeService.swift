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

    /// Pool of 25 daily goals. Picked one-per-day from a per-year shuffle, so the
    /// order varies year to year but is stable across launches within a day, and
    /// every goal appears before any repeats.
    static let catalog: [(kind: DailyChallenge.Kind, target: Int)] = [
        (.minutes, 30),  (.minutes, 45),  (.minutes, 60),  (.minutes, 75),
        (.minutes, 90),  (.minutes, 100), (.minutes, 120), (.minutes, 135),
        (.minutes, 150), (.minutes, 180),
        (.sessions, 2),  (.sessions, 3),  (.sessions, 4),  (.sessions, 5),
        (.sessions, 6),  (.sessions, 7),
        (.longSession, 20), (.longSession, 25), (.longSession, 30), (.longSession, 35),
        (.longSession, 40), (.longSession, 45), (.longSession, 50), (.longSession, 60),
        (.longSession, 90)
    ]

    private static func make(for dateKey: String) -> DailyChallenge {
        // Deterministic selection: a per-year seeded shuffle of the catalog gives a
        // varied (non-sequential) order that's stable across launches, and indexing
        // by day-of-year cycles through all 25 goals before any repeat.
        let calendar = Calendar.current
        let now = Date()
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let year = calendar.component(.year, from: now)

        var generator = SeededGenerator(seed: UInt64(year))
        let order = Array(catalog.indices).shuffled(using: &generator)
        let template = catalog[order[(dayOfYear - 1) % order.count]]
        return DailyChallenge(dateKey: dateKey, kind: template.kind, target: template.target)
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}

/// Reproducible RNG (SplitMix64) so `shuffled(using:)` yields the same order for a
/// given seed on every launch — unlike the system RNG, which is unseedable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
