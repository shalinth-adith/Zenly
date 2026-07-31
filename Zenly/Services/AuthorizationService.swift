//
//  AuthorizationService.swift
//  Zenly
//
//  Wraps FamilyControls AuthorizationCenter. We request `.individual`
//  authorization (this device's own user authorizes via Face ID / passcode) —
//  appropriate for a self-directed focus app, not a parent/child setup.
//

import Foundation
import FamilyControls
import Observation

@Observable
@MainActor
final class AuthorizationService {
    private(set) var status: AuthorizationStatus

    private let center = AuthorizationCenter.shared

    init() {
        status = center.authorizationStatus
    }

    var isAuthorized: Bool {
        #if DEBUG
        // Screen Time cannot be granted on Simulator, which otherwise makes the
        // session, complete and ended-early screens impossible to see or test —
        // "Begin focus" stays disabled forever. Reporting authorized lets the UI
        // be driven; the blocking calls underneath still no-op there, so nothing
        // is actually enforced.
        //
        // Two gates: compiled out of Release entirely, and inert unless the test
        // runner passes the flag.
        if Self.uiTestBypass { return true }
        #endif
        return status == .approved
    }

    #if DEBUG
    /// No leading dash: NSUserDefaults reads `-key value` pairs out of the
    /// argument list, so a lone `-flag` corrupts the defaults it parses.
    static let uiTestBypass = ProcessInfo.processInfo
        .arguments.contains("ZenlyUITestBypassScreenTime")
    #endif

    /// Triggers the system Screen Time consent prompt. Safe to call when already
    /// approved (it's a no-op). Updates `status` from the live center afterwards.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            print("[Zenly] Authorization request failed: \(error)")
        }
        status = center.authorizationStatus
    }

    /// Re-reads the live authorization status (e.g. after returning from Settings).
    func refresh() {
        status = center.authorizationStatus
    }
}
