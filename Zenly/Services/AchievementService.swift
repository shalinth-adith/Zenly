//
//  AchievementService.swift
//  Zenly
//
//  Evaluates the badge catalog against session history and persists newly-earned
//  badges (Core Data). Evaluation is idempotent — it recomputes from source data
//  rather than tracking awards imperatively.
//

import Foundation
import CoreData
import Observation

@Observable
@MainActor
final class AchievementService {
    private(set) var earnedKeys: Set<String> = []
    private var earnedDates: [String: Date] = [:]

    private let context: NSManagedObjectContext
    private let history: SessionHistory

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         history: SessionHistory? = nil) {
        self.context = context
        self.history = history ?? SessionHistory()
        load()
    }

    var definitions: [BadgeDefinition] { BadgeCatalog.all }

    func isEarned(_ key: String) -> Bool { earnedKeys.contains(key) }
    func earnedDate(_ key: String) -> Date? { earnedDates[key] }

    /// Recompute against current history; persist + return any newly-earned badges.
    @discardableResult
    func evaluate() -> [BadgeDefinition] {
        let sessions = history.completedFocusSessions()
        let totalSessions = sessions.count
        let totalMinutes = sessions.reduce(0) { $0 + Int($1.completedMinutes) }
        let streak = history.currentStreak()
        let todayMinutes = history.todayFocusMinutes()

        var newlyEarned: [BadgeDefinition] = []
        for badge in BadgeCatalog.all where !earnedKeys.contains(badge.id) {
            if meets(badge.requirement,
                     totalSessions: totalSessions,
                     totalMinutes: totalMinutes,
                     streak: streak,
                     todayMinutes: todayMinutes) {
                persist(badge.id)
                newlyEarned.append(badge)
            }
        }
        if !newlyEarned.isEmpty { load() }
        return newlyEarned
    }

    // MARK: - Private

    private func meets(_ requirement: BadgeDefinition.Requirement,
                       totalSessions: Int, totalMinutes: Int,
                       streak: Int, todayMinutes: Int) -> Bool {
        switch requirement {
        case .firstSession: return totalSessions >= 1
        case .streak(let n): return streak >= n
        case .totalSessions(let n): return totalSessions >= n
        case .totalMinutes(let n): return totalMinutes >= n
        case .minutesInDay(let n): return todayMinutes >= n
        }
    }

    private func persist(_ key: String) {
        let badge = EarnedBadge(context: context)
        badge.id = UUID()
        badge.key = key
        badge.earnedAt = Date()
        do { try context.save() }
        catch { print("[Zenly] AchievementService save failed: \(error)") }
    }

    private func load() {
        let request = EarnedBadge.fetchRequest()
        let earned = (try? context.fetch(request)) ?? []
        earnedKeys = Set(earned.compactMap { $0.key })
        earnedDates = Dictionary(earned.compactMap { badge in
            guard let key = badge.key, let date = badge.earnedAt else { return nil }
            return (key, date)
        }, uniquingKeysWith: { first, _ in first })
    }
}
