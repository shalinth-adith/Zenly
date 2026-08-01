//
//  ShieldMessage.swift
//  Zenly (shared: app + ZenlyShield)
//
//  Every word on the block screen (Quiet spec, screen 03).
//
//  The comp's voice here is the whole point of the screen: it does not scold,
//  it does not congratulate, and it never says "blocked". It states that the
//  thing you reached for is fine and will still be there, and it says when you
//  get it back — a clock time, so the wait is finite rather than open-ended.
//
//  The comp lays this out as four lines:
//
//      BACK AT 7:43                      ← eyebrow, tracked, uppercase
//      Your place is kept.               ← 25px, the sentence that does the work
//      Instagram waits exactly as you left it — same post, same scroll.
//      16 minutes.
//
//  `ShieldConfiguration` gives us a title and a subtitle and nothing else, so
//  the eyebrow's *content* survives as the closing line of the subtitle even
//  though its position cannot. It is the one line whose place in the stack we
//  have to give up.
//
//  The user's own message from Settings, when set, is added in the middle.
//

import Foundation

enum ShieldMessage {
    static let storageKey = "shieldMessage"

    /// The headline — the comp's, verbatim.
    ///
    /// Four words that answer the actual worry. Not "Instagram is blocked", not
    /// "Stay focused": the thing you were in the middle of is still there.
    static func title() -> String {
        "Your place is kept."
    }

    /// The lines under it: what is paused, and when it comes back.
    ///
    /// `subject` is the app name or domain iOS gives us. Naming it is the whole
    /// point of the comp's line, so it is always shown. A custom message from
    /// Settings is added underneath rather than swapped in for it; neither one
    /// ever displaces the return line, which is what the person standing there
    /// is really waiting to read.
    static func subtitle(subject: String, custom: String) -> String {
        var lines = ["\(subject) waits exactly as you left it — same place, same scroll."]

        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { lines.append(trimmed) }

        if let returnLine { lines.append(returnLine) }
        return lines.joined(separator: "\n\n")
    }

    /// "Back at 7:43 · 16 minutes" — the comp's eyebrow and its closing line,
    /// folded together because we only have one slot left to put them in.
    ///
    /// Nil when nothing is running: quoting a countdown that has already expired
    /// is worse than saying nothing, and a stale time is exactly what a shield
    /// left standing after a session ends would show.
    private static var returnLine: String? {
        guard let minutes = ActiveSessionInfo.remainingMinutes,
              let endsAt = ActiveSessionInfo.endsAt else { return nil }

        let clock = DateFormatter()
        clock.locale = .autoupdatingCurrent
        clock.setLocalizedDateFormatFromTemplate("jm")

        let remaining = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        return "Back at \(clock.string(from: endsAt)) · \(remaining)"
    }
}
