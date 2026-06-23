//
//  BadgeCatalog.swift
//  Zenly
//
//  Static catalog of earnable badges + the metrics they unlock against. The
//  AchievementService evaluates these against session history; GameKit reporting
//  can be layered on later without changing the catalog.
//

import Foundation

struct BadgeDefinition: Identifiable {
    enum Requirement {
        case firstSession
        case streak(Int)
        case totalSessions(Int)
        case totalMinutes(Int)
        case minutesInDay(Int)
    }

    let id: String
    let title: String
    let detail: String
    let systemImage: String
    let accentHex: String
    let requirement: Requirement
}

enum BadgeCatalog {
    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "first_focus", title: "First Focus",
                        detail: "Complete your first session", systemImage: "sparkles",
                        accentHex: "1A3FA8", requirement: .firstSession),
        BadgeDefinition(id: "streak_3", title: "Getting Going",
                        detail: "3-day focus streak", systemImage: "flame.fill",
                        accentHex: "FF9F0A", requirement: .streak(3)),
        BadgeDefinition(id: "streak_7", title: "On a Roll",
                        detail: "7-day focus streak", systemImage: "flame.fill",
                        accentHex: "FF375F", requirement: .streak(7)),
        BadgeDefinition(id: "streak_30", title: "Unstoppable",
                        detail: "30-day focus streak", systemImage: "crown.fill",
                        accentHex: "FFD60A", requirement: .streak(30)),
        BadgeDefinition(id: "sessions_10", title: "Committed",
                        detail: "Complete 10 sessions", systemImage: "checkmark.circle.fill",
                        accentHex: "34C759", requirement: .totalSessions(10)),
        BadgeDefinition(id: "sessions_50", title: "Focused Mind",
                        detail: "Complete 50 sessions", systemImage: "checkmark.seal.fill",
                        accentHex: "00C7BE", requirement: .totalSessions(50)),
        BadgeDefinition(id: "minutes_300", title: "Five Hours Deep",
                        detail: "Focus for 5 hours total", systemImage: "hourglass",
                        accentHex: "AF52DE", requirement: .totalMinutes(300)),
        BadgeDefinition(id: "power_hour", title: "Power Hour",
                        detail: "Focus 60 minutes in one day", systemImage: "bolt.fill",
                        accentHex: "1A3FA8", requirement: .minutesInDay(60))
    ]
}
