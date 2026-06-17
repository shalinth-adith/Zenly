//
//  ChallengeIntent.swift
//  Zenly
//
//  Exposes the daily challenge to Siri / Shortcuts via AppIntents.
//

import AppIntents

struct TodaysChallengeIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Focus Challenge"
    static var description = IntentDescription("Check today's Zenly focus challenge and your progress.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = ChallengeService()
        let challenge = service.challenge
        if service.isComplete {
            return .result(dialog: "Done! You completed today's challenge: \(challenge.title).")
        } else {
            return .result(dialog: "Today's challenge: \(challenge.title). You're at \(service.progress) of \(challenge.target).")
        }
    }
}

struct ZenlyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodaysChallengeIntent(),
            phrases: [
                "Check my \(.applicationName) challenge",
                "What's my \(.applicationName) focus challenge"
            ],
            shortTitle: "Today's Challenge",
            systemImageName: "checklist"
        )
    }
}
