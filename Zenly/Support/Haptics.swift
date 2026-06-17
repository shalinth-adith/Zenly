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
}
