//
//  DeviceActivityMonitorExtension.swift
//  ZenlyMonitor
//
//  Runs in a separate process. When a monitored interval (a Pomodoro focus
//  session or a recurring schedule) starts, it applies that activity's shields;
//  when the interval ends, it clears them. The selection for each activity is
//  read from the shared App-Group map (ActivityShieldStore) — the extension has
//  no access to the app's in-memory state.
//

import Foundation
import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .zenly)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Weekday filtering: recurring schedules monitor daily but only apply on
        // selected weekdays (mask 0 = every day, used by one-off sessions).
        let mask = ActivityShieldStore.weekdaysMask(for: activity.rawValue)
        if mask != 0 {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard (mask & (1 << weekday)) != 0 else { return }
        }

        // Reconcile to the union of every currently-active enforcer rather than
        // overwriting the store, so a newly-started window composes with any that
        // are already open instead of clobbering them.
        ShieldReconciler.reconcile(store)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Re-assert whatever is STILL active instead of clearing the whole store —
        // otherwise ending one window (or the one-off focus session) lifts a
        // schedule that is still in its window. Runs even if the app was killed.
        ShieldReconciler.reconcile(store)
    }
}
