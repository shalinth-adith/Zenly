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
    /// `subject` is the app name or domain iOS gives us. Naming it is the whole
    /// point of the comp's line — "Instagram will be exactly where you left it"
    /// answers the actual worry — so it is always shown. A custom message from
    /// Settings is added underneath rather than swapped in for it; neither one
    /// ever displaces the remaining-time line, which is what the person
    /// standing there is really waiting to read.
    static func subtitle(subject: String, custom: String) -> String {
        var lines = ["\(subject) will be exactly where you left it — unchanged, unhurried."]

        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append(trimmed) }

        if let minutes = ActiveSessionInfo.remainingMinutes {
            lines.append(minutes == 1 ? "1 minute of quiet remains."
                                      : "\(minutes) minutes of quiet remain.")
        }
        return lines.joined(separator: "\n\n")
    }
}
