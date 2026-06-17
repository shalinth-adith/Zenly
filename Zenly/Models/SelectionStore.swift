//
//  SelectionStore.swift
//  Zenly
//
//  Persists the user's blocked app/category/website selection to the App Group
//  container so both the main app and the extensions read the same set.
//

import Foundation
import FamilyControls

enum SelectionStore {
    private static let key = "blockSelection"

    static func save(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}
