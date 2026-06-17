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
    let wasCompleted: Bool
    let endedEarly: Bool
    let streak: Int
}
