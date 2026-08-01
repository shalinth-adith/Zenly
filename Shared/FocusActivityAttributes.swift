//
//  FocusActivityAttributes.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  Live Activity model for the running focus/break timer. The app requests/ends
//  the activity; the widget extension renders it (Lock Screen + Dynamic Island).
//
//  The Quiet spec (screen 15) names four states the card can be in: under way,
//  last stretch, paused by you, and finished. "Last stretch" is derived from the
//  countdown rather than stored — the other three are phases.
//

import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
    /// What the live timer represents.
    enum Phase: String, Codable, Hashable {
        case focus      // a running focus session
        case breakTime  // a running break
        case upcoming   // counting down to a scheduled focus window's start
        case paused     // held by the user; the countdown is frozen
        /// No longer produced. A finished session now clears the Lock Screen
        /// instead of leaving a card behind. Kept only so a card written by the
        /// previous build still decodes — dropping the case would fail the
        /// decode and strand exactly the timer this is meant to clear.
        case finished
    }

    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var phase: Phase
        /// Seconds still to run. Only meaningful while `paused` (where a date
        /// range can't count down) and when `finished` (where it is the time
        /// that was kept). Nil for the live phases, which count themselves.
        var frozenSeconds: TimeInterval?

        init(startDate: Date,
             endDate: Date,
             phase: Phase,
             frozenSeconds: TimeInterval? = nil) {
            self.startDate = startDate
            self.endDate = endDate
            self.phase = phase
            self.frozenSeconds = frozenSeconds
        }

        /// Hand-decoded so an activity started by an older build — which wrote
        /// no `frozenSeconds` — still renders, instead of failing to decode and
        /// stranding a timer on the Lock Screen.
        public init(from decoder: Decoder) throws {
            let box = try decoder.container(keyedBy: CodingKeys.self)
            startDate = try box.decode(Date.self, forKey: .startDate)
            endDate = try box.decode(Date.self, forKey: .endDate)
            phase = try box.decode(Phase.self, forKey: .phase)
            frozenSeconds = try box.decodeIfPresent(TimeInterval.self, forKey: .frozenSeconds)
        }

        /// The comp's "last stretch": the closing minutes, where the card warms
        /// to the tone and the copy stops being neutral.
        var isLastStretch: Bool {
            guard phase == .focus else { return false }
            let total = endDate.timeIntervalSince(startDate)
            let left = endDate.timeIntervalSinceNow
            guard total > 0, left > 0 else { return false }
            return left <= max(60, min(300, total * 0.1))
        }
    }

    var profileName: String
    var accentHex: String
}
