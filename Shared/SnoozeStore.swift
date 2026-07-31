//
//  SnoozeStore.swift
//  Zenly (shared: app + shield action + monitor)
//
//  "I need it for 5 minutes" (Quiet spec, screen 03).
//
//  A snooze is stored as data with an expiry, never as a change to the shield
//  rules themselves. That ordering matters: the shield is always recomputed
//  from what is *currently* true, so an expired snooze simply stops being
//  returned and the app is blocked again by the next reconcile. There is no
//  state to forget to undo.
//
//  Worst case, if nothing reconciles at the five-minute mark, the app stays
//  reachable until something does — at the latest when the session ends and
//  the whole store is torn down. The failure is bounded, and it fails toward
//  the user rather than toward a permanently unblocked phone.
//

import Foundation
import ManagedSettings

enum SnoozeStore {
    private static let key = "shieldSnoozes"

    private struct Entry: Codable {
        let token: Data
        let until: Date
    }

    /// Let one app through for `minutes`, replacing any snooze it already has.
    static func snooze(_ token: ApplicationToken, minutes: Int, now: Date = Date()) {
        guard let encoded = try? JSONEncoder().encode(token) else { return }
        var entries = load().filter { $0.token != encoded && $0.until > now }
        entries.append(Entry(token: encoded, until: now.addingTimeInterval(TimeInterval(minutes * 60))))
        save(entries)
    }

    /// The apps currently allowed through. Expired entries are dropped on read,
    /// so nothing has to remember to clean up.
    static func activeTokens(_ now: Date = Date()) -> Set<ApplicationToken> {
        let live = load().filter { $0.until > now }
        return Set(live.compactMap { try? JSONDecoder().decode(ApplicationToken.self, from: $0.token) })
    }

    /// When the earliest snooze runs out — what to re-check at.
    static func nextExpiry(_ now: Date = Date()) -> Date? {
        load().map(\.until).filter { $0 > now }.min()
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }

    // MARK: - Private

    private static func load() -> [Entry] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    private static func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}
