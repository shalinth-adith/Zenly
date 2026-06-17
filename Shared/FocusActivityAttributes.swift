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
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var isBreak: Bool
    }

    var profileName: String
    var accentHex: String
}
