//
//  PersistedFocusSession.swift
//  Zenly
//
//  Snapshot of the in-flight focus session, saved to the App Group so it can be
//  recorded/restored even if iOS terminates the app while it's backgrounded
//  during a session (which is common — the user is in another app).
//

import Foundation

struct PersistedFocusSession: Codable {
    var startedAt: Date
    var focusMinutes: Int
    var breakMinutes: Int
    var isStrict: Bool
    var profileName: String
    var accentHex: String
}

enum FocusSessionStore {
    private static let key = "activeFocusSession"

    static func save(_ session: PersistedFocusSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func load() -> PersistedFocusSession? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedFocusSession.self, from: data)
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}
