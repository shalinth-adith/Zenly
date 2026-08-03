//
//  ShieldActionExtension.swift
//  ZenlyShieldAction
//
//  Handles taps on the block screen's button (Quiet spec, screen 03).
//
//  There is one button — "Back to focus" — and it closes the app you reached
//  for. Every action closes, whichever overload iOS routes it to.
//
//  There used to be a second button offering five minutes with the app, backed
//  by a snooze store with an expiry. It is gone. Granting a pass means naming
//  the app to exempt, and the only currency `shield.applicationCategories =
//  .all(except:)` accepts is an `ApplicationToken` — which Screen Time does not
//  hand out when the shield came from a category. "Block everything" is a
//  category shield and is the default on all four profiles, so the door was a
//  control that closed the app and changed nothing on nearly every block screen
//  anyone would ever see. See `ShieldTheme.configuration` for the measurement.
//
//  What remains is small enough to be obviously correct, which is the right
//  shape for a process iOS spawns for a fraction of a second and cannot be
//  debugged from.
//

import Foundation
import ManagedSettings
import ManagedSettingsUI

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        close(completionHandler)
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        close(completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        close(completionHandler)
    }

    /// Reaching the shield at all is the thing worth counting — Insights reports
    /// it as an attempt — and then the app closes.
    private func close(_ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        DistractionLog.recordAttempt()
        completionHandler(.close)
    }
}
