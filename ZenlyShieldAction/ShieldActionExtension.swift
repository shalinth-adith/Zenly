//
//  ShieldActionExtension.swift
//  ZenlyShieldAction
//
//  Handles taps on the block screen's buttons (Quiet spec, screen 03).
//
//  "Back to focus" closes the app you reached for. "I need it for 5 minutes"
//  lets that one app — and only that one — through for five minutes.
//
//  The unlock is deliberately expressed as data with an expiry (SnoozeStore)
//  rather than as an edit to the shield rules. Everything that applies shields
//  recomputes them from what is currently true, so when the five minutes are
//  up the snooze simply stops being returned and the next reconcile blocks the
//  app again. Nothing has to remember to undo anything.
//
//  Two things trigger that reconcile: a five-minute DeviceActivity window
//  registered here, whose `intervalDidEnd` wakes the monitor extension, and
//  the app itself on next foreground. If both were somehow missed the app
//  stays reachable only until the session ends and the store is torn down —
//  bounded, and never a permanently unblocked phone.
//

import Foundation
import DeviceActivity
import ManagedSettings
import ManagedSettingsUI

final class ShieldActionExtension: ShieldActionDelegate {
    private let store = ManagedSettingsStore(named: .zenly)
    private let snoozeMinutes = 5

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        DistractionLog.recordAttempt()
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            grantFiveMinutes(to: application)
            // Close rather than defer: the shield is stale the moment the
            // snooze lands, and reopening the app is what applies it.
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respondWithoutSnooze(action, completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respondWithoutSnooze(action, completionHandler)
    }

    /// Websites and whole categories get no five-minute door — the block screen
    /// doesn't offer one for them, and letting a category through would open far
    /// more than the one thing the user asked for.
    private func respondWithoutSnooze(_ action: ShieldAction,
                                      _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        DistractionLog.recordAttempt()
        completionHandler(action == .primaryButtonPressed ? .close : .defer)
    }

    private func grantFiveMinutes(to application: ApplicationToken) {
        SnoozeStore.snooze(application, minutes: snoozeMinutes)

        // Recompute now so the app opens, and register a window whose end wakes
        // the monitor to recompute again once the snooze has lapsed.
        ShieldReconciler.reconcile(store)
        scheduleRecheck()
    }

    private func scheduleRecheck() {
        guard let expiry = SnoozeStore.nextExpiry() else { return }
        let calendar = Calendar.current
        let center = DeviceActivityCenter()
        let name = DeviceActivityName("zenly.snooze")

        // A window that closes when the snooze does. `intervalDidEnd` in
        // ZenlyMonitor reconciles, which is what puts the shield back.
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: Date()),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: expiry),
            repeats: false
        )
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule)
    }
}
