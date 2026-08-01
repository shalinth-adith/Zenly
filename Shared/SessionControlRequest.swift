//
//  SessionControlRequest.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  The bridge behind the Live Activity's Resume / Again buttons.
//
//  A `LiveActivityIntent` is declared in the widget extension but *runs in the
//  app's process*, so the widget must be able to see the intent type while only
//  the app can see the session controller. This gives both a meeting point: the
//  app registers a handler at launch, and the intent calls through it.
//
//  If the intent fires before the app process has finished starting, the action
//  is parked in the App Group instead and consumed on the next activation — the
//  same handoff `FocusLaunchRequest` uses for the Control Center button.
//

import Foundation

enum SessionControlAction: String {
    case resume
    /// No longer produced — the "Again" button it came from is gone with the
    /// finished card. Kept because `consume()` reads a raw string out of the App
    /// Group, and an upgrade can find one parked there by the previous build.
    /// Dropping the case would turn that into a silent nil.
    case again
}

enum SessionControlRequest {
    private static let key = "pendingSessionControl"

    /// Set by the app at launch; nil in every other process.
    @MainActor static var handler: ((SessionControlAction) -> Void)?

    /// Act now if the app is listening, otherwise park it for next activation.
    @MainActor static func perform(_ action: SessionControlAction) {
        if let handler {
            handler(action)
        } else {
            AppGroup.defaults.set(action.rawValue, forKey: key)
        }
    }

    /// Take the parked action, if any. Clears it.
    static func consume() -> SessionControlAction? {
        guard let raw = AppGroup.defaults.string(forKey: key) else { return nil }
        AppGroup.defaults.removeObject(forKey: key)
        return SessionControlAction(rawValue: raw)
    }
}
