//
//  Haptics.swift
//  Zenly
//
//  Thin wrapper over UIFeedbackGenerator for celebration / transition feedback.
//

import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// For an action the app is declining to take — deleting a profile that is
    /// mid-session. Distinct from `success` on purpose: the refusal is felt
    /// before the sentence explaining it has been read.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
