//
//  FocusFilterIntent.swift
//  Zenly
//
//  iOS Focus integration: when a system Focus (e.g. Work) turns on, this filter
//  records the preferred Zenly profile to the App Group; the app switches to it
//  on next foreground. It deliberately does NOT mutate shields directly — Focus
//  filter callbacks can be missed in the background, which would risk a shield
//  stuck on. Safe by construction.
//

import AppIntents

struct ApplyFocusProfileIntent: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Zenly Focus Profile"
    static var description: IntentDescription? =
        "Switch Zenly to a focus profile while this Focus is active."

    @Parameter(title: "Profile name")
    var profileName: String?

    var displayRepresentation: DisplayRepresentation {
        if let profileName, !profileName.isEmpty {
            return DisplayRepresentation(title: "Zenly: \(profileName)")
        }
        return DisplayRepresentation(title: "Zenly profile")
    }

    func perform() async throws -> some IntentResult {
        if let profileName, !profileName.isEmpty {
            AppGroup.defaults.set(profileName, forKey: "focusFilterProfile")
        } else {
            AppGroup.defaults.removeObject(forKey: "focusFilterProfile")
        }
        return .result()
    }
}
