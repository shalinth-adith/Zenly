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

    static func set(block: FamilyActivitySelection,
                    allow: FamilyActivitySelection,
                    for activity: String) {
        var blockMap = map(blockKey)
        var allowMap = map(allowKey)
        blockMap[activity] = SelectionCodec.encode(block)
        allowMap[activity] = SelectionCodec.encode(allow)
        save(blockMap, blockKey)
        save(allowMap, allowKey)
    }

    static func block(for activity: String) -> FamilyActivitySelection {
        SelectionCodec.decode(map(blockKey)[activity])
    }

    static func allow(for activity: String) -> FamilyActivitySelection {
        SelectionCodec.decode(map(allowKey)[activity])
    }

    static func remove(for activity: String) {
        var blockMap = map(blockKey); blockMap[activity] = nil; save(blockMap, blockKey)
        var allowMap = map(allowKey); allowMap[activity] = nil; save(allowMap, allowKey)
    }

    private static func map(_ key: String) -> [String: Data] {
        AppGroup.defaults.dictionary(forKey: key) as? [String: Data] ?? [:]
    }

    private static func save(_ value: [String: Data], _ key: String) {
        AppGroup.defaults.set(value, forKey: key)
    }
}
