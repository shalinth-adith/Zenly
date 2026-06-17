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
    private static let lastAttemptKey = "distractionLastAttempt"
    private static let dedupeWindow: TimeInterval = 1.5

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

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
