//
//  ActivityShieldStore.swift
//  Zenly (shared: app + ZenlyMonitor)
//
//  App-Group-backed map from a DeviceActivityName to the selection it should
//  shield. The app writes an entry before starting monitoring; the extension
//  reads it in intervalDidStart (running in a separate process with no access
//  to the app's in-memory state). This indirection lets one extension serve
//  every Pomodoro session and recurring schedule.
//

import Foundation
import FamilyControls

enum ActivityShieldStore {
    private static let blockKey = "activityBlockMap"
    private static let allowKey = "activityAllowMap"
    private static let weekdaysKey = "activityWeekdaysMap"
    private static let blockAllKey = "activityBlockAllMap"
    private static let webKey = "activityWebDomainsMap"
    private static let startKey = "activityStartMinutesMap"
    private static let endKey = "activityEndMinutesMap"

    /// - Parameters:
    ///   - weekdaysMask: bitmask of Calendar weekdays (1=Sun…7=Sat) the activity
    ///     applies to. 0 means "every day" (used for one-off sessions).
    ///   - blockAll: when true, shield everything except the allowlist.
    ///   - allowedWebDomains: research-mode allowed sites (empty = no web filter).
    ///   - startMinutes / endMinutes: the activity's daily window as minutes-since
    ///     -midnight, so `activeActivitiesNow` can tell which activities are live
    ///     right now (needed to reconcile the shared shield store). Pass -1 for
    ///     "no window" (always active on matching weekdays).
    static func set(block: FamilyActivitySelection,
                    allow: FamilyActivitySelection,
                    blockAll: Bool,
                    allowedWebDomains: [String] = [],
                    weekdaysMask: Int = 0,
                    startMinutes: Int = -1,
                    endMinutes: Int = -1,
                    for activity: String) {
        var blockMap = map(blockKey)
        var allowMap = map(allowKey)
        blockMap[activity] = SelectionCodec.encode(block)
        allowMap[activity] = SelectionCodec.encode(allow)
        save(blockMap, blockKey)
        save(allowMap, allowKey)

        var weekdaysMap = intMap(weekdaysKey)
        weekdaysMap[activity] = weekdaysMask
        AppGroup.defaults.set(weekdaysMap, forKey: weekdaysKey)

        var blockAllMap = boolMap(blockAllKey)
        blockAllMap[activity] = blockAll
        AppGroup.defaults.set(blockAllMap, forKey: blockAllKey)

        var webMap = strListMap(webKey)
        webMap[activity] = allowedWebDomains
        AppGroup.defaults.set(webMap, forKey: webKey)

        var startMap = intMap(startKey)
        startMap[activity] = startMinutes
        AppGroup.defaults.set(startMap, forKey: startKey)

        var endMap = intMap(endKey)
        endMap[activity] = endMinutes
        AppGroup.defaults.set(endMap, forKey: endKey)
    }

    static func blockAll(for activity: String) -> Bool {
        boolMap(blockAllKey)[activity] ?? false
    }

    static func allowedWebDomains(for activity: String) -> [String] {
        strListMap(webKey)[activity] ?? []
    }

    static func block(for activity: String) -> FamilyActivitySelection {
        SelectionCodec.decode(map(blockKey)[activity])
    }

    static func allow(for activity: String) -> FamilyActivitySelection {
        SelectionCodec.decode(map(allowKey)[activity])
    }

    /// Weekday bitmask for the activity (0 = every day).
    static func weekdaysMask(for activity: String) -> Int {
        intMap(weekdaysKey)[activity] ?? 0
    }

    /// Daily window bounds as minutes-since-midnight (-1 = unset / always active).
    static func startMinutes(for activity: String) -> Int { intMap(startKey)[activity] ?? -1 }
    static func endMinutes(for activity: String) -> Int { intMap(endKey)[activity] ?? -1 }

    /// All registered activities whose window is open *right now* — the set the
    /// shared shield store should currently reflect. Used by `ShieldReconciler`
    /// (app + extension) so tearing down one activity re-asserts the rest instead
    /// of clearing the whole store.
    static func activeActivitiesNow(_ now: Date = Date()) -> [String] {
        map(blockKey).keys.filter { isActive($0, now: now) }
    }

    /// Is `activity` enforcing at `now`? Honors the weekday mask and the daily
    /// window, including windows that wrap past midnight (whose post-midnight tail
    /// belongs to the *previous* day's weekday selection).
    static func isActive(_ activity: String, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        let mask = weekdaysMask(for: activity)               // 0 = every day
        let today = cal.component(.weekday, from: now)
        func dayMatches(_ weekday: Int) -> Bool {
            mask == 0 || (mask & (1 << weekday)) != 0
        }

        let startMin = startMinutes(for: activity)
        let endMin = endMinutes(for: activity)
        // No stored window (legacy / one-off without bounds): active on any matching day.
        guard startMin >= 0, endMin >= 0, startMin != endMin else { return dayMatches(today) }

        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        if startMin < endMin {
            return dayMatches(today) && nowMin >= startMin && nowMin < endMin
        }
        // Wraps midnight: [start, 24:00) belongs to today, [00:00, end) to yesterday.
        if nowMin >= startMin { return dayMatches(today) }
        if nowMin < endMin {
            let yesterday = today == 1 ? 7 : today - 1
            return dayMatches(yesterday)
        }
        return false
    }

    static func remove(for activity: String) {
        var blockMap = map(blockKey); blockMap[activity] = nil; save(blockMap, blockKey)
        var allowMap = map(allowKey); allowMap[activity] = nil; save(allowMap, allowKey)
        var weekdaysMap = intMap(weekdaysKey); weekdaysMap[activity] = nil
        AppGroup.defaults.set(weekdaysMap, forKey: weekdaysKey)
        var blockAllMap = boolMap(blockAllKey); blockAllMap[activity] = nil
        AppGroup.defaults.set(blockAllMap, forKey: blockAllKey)
        var webMap = strListMap(webKey); webMap[activity] = nil
        AppGroup.defaults.set(webMap, forKey: webKey)
        var startMap = intMap(startKey); startMap[activity] = nil
        AppGroup.defaults.set(startMap, forKey: startKey)
        var endMap = intMap(endKey); endMap[activity] = nil
        AppGroup.defaults.set(endMap, forKey: endKey)
    }

    private static func intMap(_ key: String) -> [String: Int] {
        AppGroup.defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    private static func strListMap(_ key: String) -> [String: [String]] {
        AppGroup.defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
    }

    private static func boolMap(_ key: String) -> [String: Bool] {
        AppGroup.defaults.dictionary(forKey: key) as? [String: Bool] ?? [:]
    }

    private static func map(_ key: String) -> [String: Data] {
        AppGroup.defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    }

    private static func save(_ value: [String: Data], _ key: String) {
        AppGroup.defaults.set(value, forKey: key)
    }
}
