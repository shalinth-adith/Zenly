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

    /// - Parameters:
    ///   - weekdaysMask: bitmask of Calendar weekdays (1=Sun…7=Sat) the activity
    ///     applies to. 0 means "every day" (used for one-off sessions).
    ///   - blockAll: when true, shield everything except the allowlist.
    ///   - allowedWebDomains: research-mode allowed sites (empty = no web filter).
    static func set(block: FamilyActivitySelection,
                    allow: FamilyActivitySelection,
                    blockAll: Bool,
                    allowedWebDomains: [String] = [],
                    weekdaysMask: Int = 0,
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

    static func remove(for activity: String) {
        var blockMap = map(blockKey); blockMap[activity] = nil; save(blockMap, blockKey)
        var allowMap = map(allowKey); allowMap[activity] = nil; save(allowMap, allowKey)
        var weekdaysMap = intMap(weekdaysKey); weekdaysMap[activity] = nil
        AppGroup.defaults.set(weekdaysMap, forKey: weekdaysKey)
        var blockAllMap = boolMap(blockAllKey); blockAllMap[activity] = nil
        AppGroup.defaults.set(blockAllMap, forKey: blockAllKey)
        var webMap = strListMap(webKey); webMap[activity] = nil
        AppGroup.defaults.set(webMap, forKey: webKey)
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
