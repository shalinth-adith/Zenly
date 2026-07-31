//
//  SessionControlIntents.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  The two buttons the Quiet spec puts on the Live Activity (screen 15):
//  "Resume" on a held session and "Again" on a finished one.
//
//  Both are `LiveActivityIntent`s, so iOS runs them in the app's own process
//  without bringing the app to the foreground — tapping Resume on the Lock
//  Screen puts the shields back and the card starts counting again in place.
//

import AppIntents

struct ResumeFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Focus"
    static var description = IntentDescription("Put the shields back and start the countdown again.")
    /// Runs in-process; there is nothing for the user to come into the app for.
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionControlRequest.perform(.resume)
        return .result()
    }
}

struct RepeatFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Focus Again"
    static var description = IntentDescription("Run the session that just finished, once more.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionControlRequest.perform(.again)
        return .result()
    }
}
