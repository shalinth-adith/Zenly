//
//  SessionSummary.swift
//  Zenly
//
//  Snapshot of a just-finished focus session, shown on the celebration screen.
//

import Foundation

struct SessionSummary: Identifiable {
    let id = UUID()
    let profileName: String
    let accentHex: String
    let plannedMinutes: Int
    let completedMinutes: Int
    /// Time actually focused, to the second, with any pause subtracted.
    ///
    /// The ended-early screen (Quiet spec 04b) puts a clock inside its ring —
    /// the comp reads `2:24`, not `2`. Rounding to whole minutes there loses the
    /// only thing the screen is arguing: that the part you did was real. Two
    /// minutes and twenty-four seconds is not "two minutes", and on a session
    /// abandoned after ninety seconds it is not "one" either.
    let completedSeconds: Int
    let wasCompleted: Bool
    let endedEarly: Bool
    let streak: Int

    /// "2:24" — the comp's ring label.
    var clock: String {
        let seconds = max(0, completedSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
