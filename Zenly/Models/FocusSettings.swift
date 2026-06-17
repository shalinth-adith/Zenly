//
//  FocusSettings.swift
//  Zenly
//
//  Lightweight user preferences for the blocking engine, persisted to the App
//  Group so extensions can read them too (e.g. strict mode informs override UX).
//

import Foundation

enum FocusSettings {
    private static let strictModeKey = "strictMode"

    /// When true, stopping an active focus session requires a 5s delay + an
    /// explicit confirmation (with a streak-loss warning).
    static var isStrictMode: Bool {
        get { AppGroup.defaults.bool(forKey: strictModeKey) }
        set { AppGroup.defaults.set(newValue, forKey: strictModeKey) }
    }
}
