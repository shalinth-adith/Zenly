//
//  ShieldReconciler.swift
//  Zenly (shared: app + ZenlyMonitor)
//
//  Single source of truth for "what should be shielded right now". Both the app
//  (when a focus session ends, or a schedule is disabled/deleted) and the
//  DeviceActivityMonitor extension (when any interval ends) call `reconcile`
//  instead of blindly clearing the shared ManagedSettingsStore.
//
//  Why: the recurring-schedule monitor and the in-app focus session both write
//  shields to the SAME store. Clearing the whole store on any teardown wiped a
//  schedule's still-active block — so blocking survived only while the app was
//  foregrounded. Reconciling to the union of every currently-active enforcer
//  fixes that: ending one never lifts another that is still in its window.
//

import Foundation
import FamilyControls
import ManagedSettings

enum ShieldReconciler {
    /// Recompute the shield state from every activity whose window is open now and
    /// apply exactly that. No active activities → clear.
    static func reconcile(_ store: ManagedSettingsStore, now: Date = Date()) {
        let active = ActivityShieldStore.activeActivitiesNow(now)

        guard !active.isEmpty else {
            ShieldApplier.clear(store)
            return
        }

        if active.count == 1 {
            let a = active[0]
            ShieldApplier.apply(block: ActivityShieldStore.block(for: a),
                                allow: ActivityShieldStore.allow(for: a),
                                blockAll: ActivityShieldStore.blockAll(for: a),
                                allowedWebDomains: ActivityShieldStore.allowedWebDomains(for: a),
                                to: store)
            return
        }

        // Union of several overlapping enforcers. Block = union of everything any
        // active enforcer blocks; allow = only what ALL of them allow (an app one
        // enforcer blocks must stay blocked); web filter = union of allowed sites.
        var blockApps = Set<ApplicationToken>()
        var blockCategories = Set<ActivityCategoryToken>()
        var blockWebDomains = Set<WebDomainToken>()
        var anyBlockAll = false
        var allowedApps: Set<ApplicationToken>?
        var allowedWeb = Set<String>()

        for a in active {
            let block = ActivityShieldStore.block(for: a)
            blockApps.formUnion(block.applicationTokens)
            blockCategories.formUnion(block.categoryTokens)
            blockWebDomains.formUnion(block.webDomainTokens)

            anyBlockAll = anyBlockAll || ActivityShieldStore.blockAll(for: a)

            let allow = ActivityShieldStore.allow(for: a).applicationTokens
            allowedApps = allowedApps.map { $0.intersection(allow) } ?? allow

            allowedWeb.formUnion(ActivityShieldStore.allowedWebDomains(for: a))
        }

        ShieldApplier.apply(blockApps: blockApps,
                            blockCategories: blockCategories,
                            blockWebDomains: blockWebDomains,
                            allowedApps: allowedApps ?? [],
                            blockAll: anyBlockAll,
                            allowedWebDomains: Array(allowedWeb),
                            to: store)
    }
}
