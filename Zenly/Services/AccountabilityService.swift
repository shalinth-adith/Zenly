//
//  AccountabilityService.swift
//  Zenly
//
//  Friend-accountability leaderboard, built local-first behind a SocialProvider
//  boundary. LocalSocialProvider yields just the current user; a future
//  CloudKitSocialProvider (Phase 4 follow-up) yields real friends — swapping the
//  provider is the only change needed to enable sync.
//

import Foundation
import Observation

struct LeaderboardMember: Identifiable {
    let id: String
    let displayName: String
    let weeklyMinutes: Int
    let streak: Int
    let isSelf: Bool
}

protocol SocialProvider {
    var isConnected: Bool { get }
    func members(selfMinutes: Int, selfStreak: Int) -> [LeaderboardMember]
}

/// No network: only the current user. Honest empty state until CloudKit is on.
struct LocalSocialProvider: SocialProvider {
    var isConnected: Bool { false }

    func members(selfMinutes: Int, selfStreak: Int) -> [LeaderboardMember] {
        [LeaderboardMember(id: "self", displayName: "You",
                           weeklyMinutes: selfMinutes, streak: selfStreak, isSelf: true)]
    }
}

@Observable
@MainActor
final class AccountabilityService {
    private let provider: SocialProvider
    private let history: SessionHistory

    init(provider: SocialProvider = LocalSocialProvider(), history: SessionHistory? = nil) {
        self.provider = provider
        self.history = history ?? SessionHistory()
    }

    var isConnected: Bool { provider.isConnected }

    func leaderboard() -> [LeaderboardMember] {
        provider
            .members(selfMinutes: weeklyMinutes(), selfStreak: history.currentStreak())
            .sorted { $0.weeklyMinutes > $1.weeklyMinutes }
    }

    private func weeklyMinutes() -> Int {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return history.completedFocusSessions()
            .filter { ($0.startedAt ?? .distantPast) >= weekAgo }
            .reduce(0) { $0 + Int($1.completedMinutes) }
    }
}
