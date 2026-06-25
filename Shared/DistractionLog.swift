//
//  DistractionLog.swift
//  Zenly (shared: app + ZenlyShield)
//
//  Counts "distraction attempts" — each time a blocked app's shield is shown.
//  Written by the ZenlyShield extension, read by analytics. Per-day counts are
//  kept in the App Group so they survive across processes and launches.
//

import Foundation

enum DistractionLog {
    private static let countsKey = "distractionCounts"   // [yyyy-MM-dd: Int]
    private static let eventsKey = "distractionEvents"   // [epoch seconds], newest last
    private static let lastAttemptKey = "distractionLastAttempt"
    private static let dedupeWindow: TimeInterval = 1.5
    private static let maxEvents = 2000                  // ~weeks of history; bounds storage

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Records one attempt, ignoring rapid repeats (iOS may request the shield
    /// configuration more than once per app open).
    static func recordAttempt(on date: Date = Date()) {
        let last = AppGroup.defaults.double(forKey: lastAttemptKey)
        let now = date.timeIntervalSince1970
        if last > 0, now - last < dedupeWindow { return }
        AppGroup.defaults.set(now, forKey: lastAttemptKey)

        var map = counts()
        map[dayKey(date), default: 0] += 1
        AppGroup.defaults.set(map, forKey: countsKey)

        // Also keep a timestamped log so attempts can be attributed to the
        // session window they fell inside (see `attempts(from:to:)`).
        var events = eventTimestamps()
        events.append(now)
        if events.count > maxEvents { events.removeFirst(events.count - maxEvents) }
        AppGroup.defaults.set(events, forKey: eventsKey)
    }

    static func counts() -> [String: Int] {
        AppGroup.defaults.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static func count(on date: Date) -> Int {
        counts()[dayKey(date)] ?? 0
    }

    static func today() -> Int {
        count(on: Date())
    }

    // MARK: - Per-session attribution

    private static func eventTimestamps() -> [Double] {
        AppGroup.defaults.array(forKey: eventsKey) as? [Double] ?? []
    }

    /// Times a blocked app was reached for within `[start, end]`, oldest first.
    static func attempts(from start: Date, to end: Date) -> [Date] {
        let lower = start.timeIntervalSince1970
        let upper = end.timeIntervalSince1970
        return eventTimestamps()
            .filter { $0 >= lower && $0 <= upper }
            .map { Date(timeIntervalSince1970: $0) }
    }

    /// Number of distraction attempts within `[start, end]`.
    static func count(from start: Date, to end: Date) -> Int {
        attempts(from: start, to: end).count
    }

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
