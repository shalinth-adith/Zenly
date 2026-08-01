//
//  SessionControlIntents.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  The button the Live Activity carries: "Resume" on a held session.
//
//  It is a `LiveActivityIntent`, so iOS runs it in the app's own process without
//  bringing the app to the foreground — tapping Resume on the Lock Screen puts
//  the shields back and the card starts counting again in place.
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

// `RepeatFocusIntent` ("Again") was removed with the finished card it lived on.
// Repeating a session is still offered where it belongs — "Try a shorter one"
// on the ended-early summary calls `repeatLastSession` directly.
