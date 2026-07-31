//
//  PersistedFocusSession.swift
//  Zenly
//
//  Snapshot of the in-flight focus session, saved to the App Group so it can be
//  recorded/restored even if iOS terminates the app while it's backgrounded
//  during a session (which is common — the user is in another app).
//
//  It also carries what the session is *blocking*. A paused session has had its
//  shields lifted, and resuming must put back exactly the same ones — including
//  after iOS has killed and relaunched the app in between, when there is nothing
//  left in memory to rebuild them from.
//

import Foundation

struct PersistedFocusSession: Codable {
    var startedAt: Date
    var focusMinutes: Int
    var breakMinutes: Int
    var isStrict: Bool
    var profileName: String
    var accentHex: String

    /// When the user paused, if the session is currently being held.
    var pausedAt: Date?
    /// Time already spent paused, so the countdown picks up where it left off
    /// rather than charging the pause against the user.
    var pausedSeconds: TimeInterval = 0

    /// The enforcement to put back on resume (encoded FamilyActivitySelections).
    var blockData: Data?
    var allowData: Data?
    var blockAll: Bool = true
    var allowedWebDomains: [String] = []

    init(startedAt: Date,
         focusMinutes: Int,
         breakMinutes: Int,
         isStrict: Bool,
         profileName: String,
         accentHex: String,
         pausedAt: Date? = nil,
         pausedSeconds: TimeInterval = 0,
         blockData: Data? = nil,
         allowData: Data? = nil,
         blockAll: Bool = true,
         allowedWebDomains: [String] = []) {
        self.startedAt = startedAt
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.isStrict = isStrict
        self.profileName = profileName
        self.accentHex = accentHex
        self.pausedAt = pausedAt
        self.pausedSeconds = pausedSeconds
        self.blockData = blockData
        self.allowData = allowData
        self.blockAll = blockAll
        self.allowedWebDomains = allowedWebDomains
    }

    /// Decoded by hand rather than by the synthesised initialiser: a session
    /// written by an older build has none of the pause or enforcement keys, and
    /// the synthesised decoder throws on a missing key instead of falling back
    /// to the defaults above. Losing an in-flight session on upgrade would mean
    /// losing the user's focus time.
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try box.decode(Date.self, forKey: .startedAt)
        focusMinutes = try box.decode(Int.self, forKey: .focusMinutes)
        breakMinutes = try box.decode(Int.self, forKey: .breakMinutes)
        isStrict = try box.decode(Bool.self, forKey: .isStrict)
        profileName = try box.decode(String.self, forKey: .profileName)
        accentHex = try box.decode(String.self, forKey: .accentHex)
        pausedAt = try box.decodeIfPresent(Date.self, forKey: .pausedAt)
        pausedSeconds = try box.decodeIfPresent(TimeInterval.self, forKey: .pausedSeconds) ?? 0
        blockData = try box.decodeIfPresent(Data.self, forKey: .blockData)
        allowData = try box.decodeIfPresent(Data.self, forKey: .allowData)
        blockAll = try box.decodeIfPresent(Bool.self, forKey: .blockAll) ?? true
        allowedWebDomains = try box.decodeIfPresent([String].self, forKey: .allowedWebDomains) ?? []
    }
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
