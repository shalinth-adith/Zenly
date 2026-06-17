//
//  SelectionStore.swift
//  Zenly
//
//  Persists FamilyActivitySelections to the App Group container so both the main
//  app and the extensions read the same sets. Two keyed selections:
//  `.block` (what to shield) and `.allow` (always-allowed exceptions).
//

import Foundation
import FamilyControls

enum SelectionStore {
    enum Key: String {
        case block = "blockSelection"
        case allow = "allowSelection"
    }

    static func save(_ selection: FamilyActivitySelection, for key: Key) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: key.rawValue)
    }

    static func load(_ key: Key) -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: key.rawValue),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func clear(_ key: Key) {
        AppGroup.defaults.removeObject(forKey: key.rawValue)
    }
}
