//
//  ShieldTheme.swift
//  ZenlyShield
//
//  Builds Zenly's calm, redirecting shield. ShieldConfiguration is a fixed set
//  of fields (background, blur, icon, title, subtitle, one primary button) that
//  iOS renders in its own process — so the design lives entirely in these values.
//
//  Colors are defined here as UIColor literals because app-extension targets
//  don't share the app's asset catalog. Keep this palette in sync with the app's
//  accent if it changes.
//

import UIKit
import ManagedSettingsUI

enum ShieldTheme {
    // Calm deep-indigo backdrop with a soft periwinkle accent — not alarming red.
    static let background = UIColor(red: 0.07, green: 0.09, blue: 0.16, alpha: 1.0)
    static let accent = UIColor(red: 0.51, green: 0.58, blue: 0.98, alpha: 1.0)
    static let primaryText = UIColor.white
    static let secondaryText = UIColor(white: 1.0, alpha: 0.72)

    private static var icon: UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        return UIImage(systemName: "moon.stars.fill", withConfiguration: config)?
            .withTintColor(accent, renderingMode: .alwaysOriginal)
    }

    /// A calm shield personalized with what's being paused (`subject` = app name
    /// or website domain, when iOS provides one).
    static func configuration(subject: String?) -> ShieldConfiguration {
        let name = subject ?? "This app"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: icon,
            title: ShieldConfiguration.Label(text: "Stay in your focus", color: primaryText),
            subtitle: ShieldConfiguration.Label(
                text: "\(name) is paused while Zenly keeps you focused.\nYou've got this.",
                color: secondaryText
            ),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Back to focus", color: .white),
            primaryButtonBackgroundColor: accent
        )
    }
}
