//
//  BlockingService.swift
//  Zenly
//
//  Applies and clears app/category/website shields via the named
//  ManagedSettingsStore. Setting a shield is effectively instant: the next time
//  the user launches a shielded app, iOS shows the shield instead.
//

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BlockingService {
    private let store = ManagedSettingsStore(named: .zenly)

    /// Shield everything in the given selection. Empty facets are set to `nil`
    /// so we never apply an empty (but non-nil) shield set.
    func startBlocking(_ selection: FamilyActivitySelection) {
        store.shield.applications =
            selection.applicationTokens.isEmpty ? nil : selection.applicationTokens

        store.shield.applicationCategories =
            selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)

        store.shield.webDomains =
            selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    /// Remove every shield this store applied.
    func stopBlocking() {
        store.clearAllSettings()
    }
}
