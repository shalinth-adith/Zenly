//
//  FocusLaunchRequest.swift
//  Zenly (shared: app + ZenlyWidget)
//
//  Handoff flag for starting a focus session from outside the app (App Intent /
//  Control Center / Siri). The intent sets it + opens the app; the app consumes
//  it on becoming active and starts the session with the active profile.
//

import Foundation

enum FocusLaunchRequest {
    private static let key = "pendingFocusStart"

    static func request() {
        AppGroup.defaults.set(true, forKey: key)
    }

    /// Returns true once if a start was requested, then clears it.
    static func consume() -> Bool {
        guard AppGroup.defaults.bool(forKey: key) else { return false }
        AppGroup.defaults.set(false, forKey: key)
        return true
    }
}
