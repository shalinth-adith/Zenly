//
//  StartFocusIntent.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  Starts a focus session with the active profile. Powers Siri/Spotlight/
//  Shortcuts and the Control Center button. Runs by opening the app, which
//  consumes the handoff flag and begins the session.
//

import AppIntents

struct StartFocusIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Focus Session"
    static var description = IntentDescription("Starts a Zenly focus session with your active profile.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        FocusLaunchRequest.request()
        return .result()
    }
}
