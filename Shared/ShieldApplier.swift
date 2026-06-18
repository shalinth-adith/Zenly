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
    /// - Parameter blockAll: when true, shield *every* (non-system) app and all
    ///   websites except the allowlist — "block everything" focus mode. The
    ///   controlling app (Zenly) and system apps are auto-exempt by the OS.
    static func apply(block: FamilyActivitySelection,
                      allow: FamilyActivitySelection,
                      blockAll: Bool,
                      allowedWebDomains: [String] = [],
                      to store: ManagedSettingsStore) {
        let allowed = allow.applicationTokens
        let webAllow = Set(allowedWebDomains.map { WebDomain(domain: $0) })
        let researchMode = !webAllow.isEmpty

        // Research mode: allow ONLY these sites in Safari, block the rest of the
        // web. Safari itself stays usable (system app, never shielded by .all()).
        store.webContent.blockedByFilter = researchMode ? .all(except: webAllow) : nil

        if blockAll {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: allowed)
            store.shield.webDomains = nil
            // Don't shield-all web when the filter already restricts it.
            store.shield.webDomainCategories = researchMode ? nil : .all()
            return
        }

        let apps = block.applicationTokens.subtracting(allowed)
        store.shield.applications = apps.isEmpty ? nil : apps

        store.shield.applicationCategories = block.categoryTokens.isEmpty
            ? nil
            : .specific(block.categoryTokens, except: allowed)

        store.shield.webDomains = block.webDomainTokens.isEmpty ? nil : block.webDomainTokens
        store.shield.webDomainCategories = nil
    }

    static func clear(_ store: ManagedSettingsStore) {
        store.clearAllSettings()
    }
}
