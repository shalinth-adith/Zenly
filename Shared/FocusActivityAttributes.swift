//
//  FocusActivityAttributes.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  Live Activity model for the running focus/break timer. The app requests/ends
//  the activity; the widget extension renders it (Lock Screen + Dynamic Island).
//

import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
    /// What the live timer represents.
    enum Phase: String, Codable, Hashable {
        case focus      // a running focus session
        case breakTime  // a running break
        case upcoming   // counting down to a scheduled focus window's start
    }

    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var phase: Phase
    }

    var profileName: String
    var accentHex: String
}
