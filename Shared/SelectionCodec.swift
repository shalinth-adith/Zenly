//
//  SelectionCodec.swift
//  Zenly (shared: app + ZenlyMonitor)
//
//  Encodes/decodes FamilyActivitySelection to Data for storage in Core Data
//  Binary attributes and the App-Group activity map.
//

import Foundation
import FamilyControls

enum SelectionCodec {
    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    static func decode(_ data: Data?) -> FamilyActivitySelection {
        guard let data,
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }
}
