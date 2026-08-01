//
//  PausedApp.swift
//  Zenly (shared: app + ZenlyShield + ZenlyShieldAction)
//
//  The last app a shield stood in front of.
//
//  `DistractionLog` counts attempts; this remembers the one that just happened
//  — its name, when it happened, and its token — so the app can put up the
//  Quiet spec's screen 03 at full size when you come back to it.
//
//  That screen exists in two places for a reason. iOS draws the real shield
//  from a `ShieldConfiguration`: nine primitive fields, laid out in another
//  process, with the icon clamped to an ~80pt box. The comp's 44 x 302 ribbon
//  hanging off the top edge cannot be built there — see `ShieldRibbon`. It can
//  be built here, on a surface the app owns, at exactly the size it was drawn.
//
//  The token is kept so the in-app screen can offer the same five-minute door
//  the shield does, rather than showing a button that only looks like the comp.
//

import Foundation
import ManagedSettings

enum PausedApp {
    private static let nameKey = "pausedAppName"
    private static let atKey = "pausedAppAt"
    private static let tokenKey = "pausedAppToken"
    private static let seenKey = "pausedAppSeenAt"

    /// How recent a pause has to be for the app to still be talking about it.
    ///
    /// Long enough to survive putting the phone down and picking Zen-ly up;
    /// short enough that opening the app an hour later does not greet you with
    /// news about something you have forgotten.
    static let window: TimeInterval = 10 * 60

    /// Called by the shield extension as it puts the screen up.
    static func record(name: String?, token: ApplicationToken? = nil, at date: Date = Date()) {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        AppGroup.defaults.set(trimmed, forKey: nameKey)
        AppGroup.defaults.set(date.timeIntervalSince1970, forKey: atKey)

        if let token, let data = try? JSONEncoder().encode(token) {
            AppGroup.defaults.set(data, forKey: tokenKey)
        } else {
            AppGroup.defaults.removeObject(forKey: tokenKey)
        }
    }

    /// The pause worth showing, or nil.
    ///
    /// Nil once it is outside the window, and nil once the app has shown it —
    /// the screen is a greeting, not a log, and a greeting that repeats every
    /// time you open the app is nagging.
    static func pending(now: Date = Date()) -> (name: String, at: Date)? {
        let at = AppGroup.defaults.double(forKey: atKey)
        guard at > 0,
              let name = AppGroup.defaults.string(forKey: nameKey), !name.isEmpty
        else { return nil }

        let when = Date(timeIntervalSince1970: at)
        guard now.timeIntervalSince(when) <= window, now >= when else { return nil }
        guard AppGroup.defaults.double(forKey: seenKey) < at else { return nil }
        return (name, when)
    }

    /// Mark the pending pause as shown.
    static func markSeen(now: Date = Date()) {
        AppGroup.defaults.set(AppGroup.defaults.double(forKey: atKey), forKey: seenKey)
    }

    /// The token of the app that was paused, when the shield recorded one.
    /// Only apps have one; websites and whole categories do not.
    static var token: ApplicationToken? {
        guard let data = AppGroup.defaults.data(forKey: tokenKey) else { return nil }
        return try? JSONDecoder().decode(ApplicationToken.self, from: data)
    }

    static func clear() {
        for key in [nameKey, atKey, tokenKey, seenKey] {
            AppGroup.defaults.removeObject(forKey: key)
        }
    }
}
