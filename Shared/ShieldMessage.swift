//
//  ShieldMessage.swift
//  Zenly (shared: app + ZenlyShield)
//
//  Every word on the block screen (Quiet spec, screen 03).
//
//  The comp's voice here is the whole point of the screen: it does not scold,
//  it does not congratulate, and it never says "blocked". It states that the
//  thing you reached for is fine and will still be there, and it says how much
//  quiet is left — a number, so the wait is finite rather than open-ended.
//
//  The user's own message from Settings, when set, replaces the default line.
//

import Foundation

enum ShieldMessage {
    static let storageKey = "shieldMessage"

    /// The headline. The comp's is a full sentence rather than a label, and it
    /// points forward ("yet") instead of back at what you just did.
    static func title() -> String {
        "Nothing on the other side of this line needs you yet."
    }

    /// The line under it: what is paused, and how long the quiet lasts.
    ///
    /// `subject` is the app name or domain iOS gives us. A custom message from
    /// Settings replaces the reassurance but never the remaining-time line —
    /// that is the part the user is actually waiting for.
    static func subtitle(subject: String, custom: String) -> String {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        let lead = trimmed.isEmpty
            ? "\(subject) will be exactly where you left it — unchanged, unhurried."
            : trimmed

        guard let minutes = ActiveSessionInfo.remainingMinutes else { return lead }
        let quiet = minutes == 1 ? "1 minute of quiet remains."
                                 : "\(minutes) minutes of quiet remain."
        return "\(lead)\n\n\(quiet)"
    }
}
