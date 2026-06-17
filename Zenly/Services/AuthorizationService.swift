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

    var isAuthorized: Bool { status == .approved }

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
