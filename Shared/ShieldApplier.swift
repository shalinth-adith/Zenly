//
//  ShieldApplier.swift
//  Zenly (shared: app + ZenlyMonitor)
//
//  Single source of truth for translating a block/allow selection into shield
//  settings on a ManagedSettingsStore. Used by the app (instant blocking) and
//  by the DeviceActivityMonitor extension (schedule-driven blocking) so both
//  apply shields identically.
//

import FamilyControls
import ManagedSettings

enum ShieldApplier {
    static func apply(block: FamilyActivitySelection,
                      allow: FamilyActivitySelection,
                      to store: ManagedSettingsStore) {
        let allowed = allow.applicationTokens

        let apps = block.applicationTokens.subtracting(allowed)
        store.shield.applications = apps.isEmpty ? nil : apps

        store.shield.applicationCategories = block.categoryTokens.isEmpty
            ? nil
            : .specific(block.categoryTokens, except: allowed)

        store.shield.webDomains = block.webDomainTokens.isEmpty ? nil : block.webDomainTokens
    }

    static func clear(_ store: ManagedSettingsStore) {
        store.clearAllSettings()
    }
}
