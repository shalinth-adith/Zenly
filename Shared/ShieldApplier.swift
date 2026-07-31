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
        apply(blockApps: block.applicationTokens,
              blockCategories: block.categoryTokens,
              blockWebDomains: block.webDomainTokens,
              allowedApps: allow.applicationTokens,
              blockAll: blockAll,
              allowedWebDomains: allowedWebDomains,
              to: store)
    }

    /// Token-based core. The selection convenience above and the multi-activity
    /// `ShieldReconciler` (which composes a *union* of several enforcers, and so
    /// can't build a synthetic `FamilyActivitySelection` — its token sets are
    /// read-only) both funnel through here, guaranteeing identical shield rules.
    static func apply(blockApps: Set<ApplicationToken>,
                      blockCategories: Set<ActivityCategoryToken>,
                      blockWebDomains: Set<WebDomainToken>,
                      allowedApps: Set<ApplicationToken>,
                      blockAll: Bool,
                      allowedWebDomains: [String],
                      to store: ManagedSettingsStore) {
        // An app the user asked for five minutes with is exempted exactly like
        // an allowed app. Folding it in here — rather than subtracting it from
        // the block list — is what makes it work under "block everything" too,
        // where the rule is a category-wide `.all(except:)` and removing a
        // token from `blockApps` would achieve nothing.
        let allowedApps = allowedApps.union(SnoozeStore.activeTokens())

        let webAllow = Set(allowedWebDomains.map { WebDomain(domain: $0) })
        let researchMode = !webAllow.isEmpty

        // Research mode: allow ONLY these sites in Safari, block the rest of the
        // web. Safari itself stays usable (system app, never shielded by .all()).
        store.webContent.blockedByFilter = researchMode ? .all(except: webAllow) : nil

        if blockAll {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: allowedApps)
            store.shield.webDomains = nil
            // Don't shield-all web when the filter already restricts it.
            store.shield.webDomainCategories = researchMode ? nil : .all()
            return
        }

        let apps = blockApps.subtracting(allowedApps)
        store.shield.applications = apps.isEmpty ? nil : apps

        store.shield.applicationCategories = blockCategories.isEmpty
            ? nil
            : .specific(blockCategories, except: allowedApps)

        store.shield.webDomains = blockWebDomains.isEmpty ? nil : blockWebDomains
        store.shield.webDomainCategories = nil
    }

    static func clear(_ store: ManagedSettingsStore) {
        store.clearAllSettings()
    }
}
