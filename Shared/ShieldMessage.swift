//
//  ShieldMessage.swift
//  Zenly (shared: app + ZenlyShield)
//
//  The user's custom shield message (set in Settings, written to the App Group,
//  read by the shield extension when rendering the blocked-app screen).
//

import Foundation

enum ShieldMessage {
    static let storageKey = "shieldMessage"

    /// The subtitle to show on the shield: the user's custom message if set,
    /// otherwise a friendly default mentioning what's paused.
    static func subtitle(subject: String, custom: String) -> String {
        let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "\(subject) is paused while Zenly keeps you focused.\nYou've got this."
    }
}
