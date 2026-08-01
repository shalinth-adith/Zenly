//
//  ActiveSessionInfo.swift
//  Zenly (shared: app + ZenlyShield)
//
//  The little the shield needs to know about the session that is blocking.
//
//  The block screen (Quiet spec, screen 03) says how much quiet is left and
//  which profile is running. The shield extension renders in its own process
//  and cannot reach the app's session controller, so the app leaves those two
//  facts in the App Group and the shield reads them.
//
//  Deliberately tiny: two values and an expiry. Anything richer would have to be
//  kept in sync across a process boundary, and a stale sentence on the shield is
//  worse than no sentence.
//

import Foundation

enum ActiveSessionInfo {
    private static let endsAtKey = "activeSessionEndsAt"
    private static let profileKey = "activeSessionProfile"

    /// Record the running session. Called on start and on resume.
    static func set(profileName: String, endsAt: Date) {
        AppGroup.defaults.set(endsAt.timeIntervalSince1970, forKey: endsAtKey)
        AppGroup.defaults.set(profileName, forKey: profileKey)
    }

    /// Forget it. Called when the session ends, and when it is paused — a held
    /// session has no shields up, so nothing should be quoting a countdown.
    static func clear() {
        AppGroup.defaults.removeObject(forKey: endsAtKey)
        AppGroup.defaults.removeObject(forKey: profileKey)
    }

    static var profileName: String? {
        guard remainingMinutes != nil else { return nil }
        let name = AppGroup.defaults.string(forKey: profileKey)
        return (name?.isEmpty ?? true) ? nil : name
    }

    /// When the quiet ends, or nil when nothing is running.
    ///
    /// The block screen's eyebrow is a clock time ("Back at 7:43") rather than a
    /// duration — a duration keeps counting in your head, a time on the clock
    /// does not.
    static var endsAt: Date? {
        let raw = AppGroup.defaults.double(forKey: endsAtKey)
        guard raw > 0 else { return nil }
        let date = Date(timeIntervalSince1970: raw)
        return date > Date() ? date : nil
    }

    /// The end that was recorded, even if it has already passed.
    ///
    /// `endsAt` goes nil the moment it lapses, which is right for the shield —
    /// it must never quote a countdown that has run out. But it makes "no
    /// session" and "a session that ended while nobody was watching"
    /// indistinguishable, and the second one has a Lock Screen card left to
    /// clear. Pausing calls `clear()`, so a held session never appears here.
    static var scheduledEnd: Date? {
        let raw = AppGroup.defaults.double(forKey: endsAtKey)
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    /// Whole minutes of quiet left, or nil when nothing is running. Rounds up so
    /// the last partial minute reads "1 minute" rather than "0".
    static var remainingMinutes: Int? {
        let raw = AppGroup.defaults.double(forKey: endsAtKey)
        guard raw > 0 else { return nil }
        let seconds = Date(timeIntervalSince1970: raw).timeIntervalSinceNow
        guard seconds > 0 else { return nil }
        return max(1, Int(ceil(seconds / 60)))
    }
}
