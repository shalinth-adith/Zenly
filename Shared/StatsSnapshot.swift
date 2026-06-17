//
//  StatsSnapshot.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  Compact snapshot of today's stats written by the app and read by the widget
//  (which can't easily reach Core Data from its own process).
//

import Foundation

struct StatsSnapshot: Codable {
    var streak: Int
    var todayMinutes: Int
    var todayAttempts: Int
    var updatedAt: Date

    static let empty = StatsSnapshot(streak: 0, todayMinutes: 0, todayAttempts: 0, updatedAt: .distantPast)
}

enum StatsStore {
    private static let key = "statsSnapshot"

    static func save(_ snapshot: StatsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func load() -> StatsSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(StatsSnapshot.self, from: data)
        else {
            return .empty
        }
        return snapshot
    }
}
