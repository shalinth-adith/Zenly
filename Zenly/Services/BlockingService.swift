//
//  BlockingService.swift
//  Zenly
//
//  Applies and clears app/category/website shields via the named
//  ManagedSettingsStore. Setting a shield is effectively instant: the next time
//  the user launches a shielded app, iOS shows Zenly's shield instead.
//

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BlockingService {
    private let store = ManagedSettingsStore(named: .zenly)

    /// Shield everything in `block`, honoring `allow` as exceptions.
    ///
    /// - Apps: shield selected apps minus any explicitly allowed.
    /// - Categories: shield selected categories, except allowed apps (so e.g.
    ///   "block all Social but keep Maps" is expressible).
    /// - Websites: shield selected domains.
    func startBlocking(_ block: FamilyActivitySelection,
                       allowing allow: FamilyActivitySelection = FamilyActivitySelection()) {
        let allowedApps = allow.applicationTokens

        let appsToShield = block.applicationTokens.subtracting(allowedApps)
        store.shield.applications = appsToShield.isEmpty ? nil : appsToShield

        store.shield.applicationCategories = block.categoryTokens.isEmpty
            ? nil
            : .specific(block.categoryTokens, except: allowedApps)

        store.shield.webDomains = block.webDomainTokens.isEmpty ? nil : block.webDomainTokens
    }

    /// Remove every shield this store applied.
    func stopBlocking() {
        store.clearAllSettings()
    }
}
