//
//  ShieldMessage.swift
//  Zenly (shared: app + ZenlyShield)
//
//  Every word on the block screen (Quiet spec, screen 03).
//
//  The comp's voice is the whole point of the screen: it does not scold, it
//  does not congratulate, and it never says "blocked". It says the thing you
//  reached for is behind a door that opens by itself, and when.
//
//      OPENS AT 7:43
//      Instagram is behind this door.
//      It opens on its own in 16 minutes. Nothing inside will have moved.
//
//  "Opens on its own" is doing the work. Nothing is being withheld from you and
//  nothing is asked of you — the door is on a timer, not a lock, and the only
//  thing between you and it is time that is already passing.
//
//  `ShieldConfiguration` gives us a title and a subtitle and nothing else, so
//  the eyebrow's *content* survives as a line of the subtitle even though its
//  position cannot. It is the one line whose place in the stack we have to give
//  up. (Screen 03b, in the app, has it where the comp puts it — see
//  `AppPausedView`.)
//
//  The user's own message from Settings, when set, is added in the middle.
//

import Foundation

enum ShieldMessage {
    static let storageKey = "shieldMessage"

    /// "Instagram is behind this door."
    ///
    /// `subject` is the app name or domain iOS gives us. Naming it is the whole
    /// point of the line — a generic "This app" would answer nothing.
    static func title(subject: String) -> String {
        "\(subject) is behind this door."
    }

    /// The lines under it: that the door opens by itself, when, and that
    /// nothing has changed on the other side.
    static func subtitle(custom: String) -> String {
        var lines: [String] = []

        if let minutes = ActiveSessionInfo.remainingMinutes {
            let time = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            lines.append("It opens on its own in \(time). Nothing inside will have moved.")
        } else {
            // No session, so no honest number to give. The reassurance still
            // holds and is the half worth keeping.
            lines.append("Nothing inside will have moved.")
        }

        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append(trimmed) }

        if let opensAt { lines.append(opensAt) }
        return lines.joined(separator: "\n\n")
    }

    /// "Opens at 7:43" — the comp's eyebrow, carried down into the subtitle
    /// because there is no third text slot to put it in.
    ///
    /// Nil when nothing is running: a door that has already opened should not
    /// still be announcing a time.
    private static var opensAt: String? {
        guard let endsAt = ActiveSessionInfo.endsAt else { return nil }
        let clock = DateFormatter()
        clock.locale = .autoupdatingCurrent
        clock.setLocalizedDateFormatFromTemplate("jm")
        return "Opens at \(clock.string(from: endsAt))"
    }
}
