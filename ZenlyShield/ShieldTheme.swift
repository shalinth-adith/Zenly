//
//  ShieldTheme.swift
//  ZenlyShield
//
//  The block screen — Quiet spec, screen 03 ("App paused").
//
//  What the comp draws and what iOS will actually render are not the same
//  thing. `ShieldConfiguration` is a fixed set of fields — background, blur,
//  one icon, a title, a subtitle, and up to two buttons — laid out by iOS in
//  its own process. The comp's thread of light down the page, its timeline
//  marks, and its absolutely-positioned editorial text are not expressible.
//
//  So this takes the comp's *voice and palette* rather than its geometry: the
//  Quiet neutral background, the profile tone on the primary button, and the
//  sentence that does the actual work — the one that tells you the thing you
//  reached for will still be there.
//
//  Colors are UIColor literals because app-extension targets don't share the
//  app's asset catalog. Keep in sync with ZTheme.Palette.
//

import UIKit
import ManagedSettingsUI

enum ShieldTheme {
    // MARK: - Quiet palette (mirrors ZTheme.Palette, dark values)

    /// Design `--bg` #0A0B0E — the same near-black the app sits on, warm, no
    /// blue cast. The old shield used a navy that no longer exists anywhere.
    static let background = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1.0)
    /// Design `--ink` #E7E8EC.
    static let primaryText = UIColor(red: 0.906, green: 0.910, blue: 0.925, alpha: 1.0)
    /// Design `--ink-2` — ink at 55%.
    static let secondaryText = primaryText.withAlphaComponent(0.55)
    /// Design `--ink-3` — ink at 30%.
    static let tertiaryText = primaryText.withAlphaComponent(0.30)
    /// Default tone: Work periwinkle #7C93E8. Overridden per profile below.
    static let defaultTone = UIColor(red: 0.486, green: 0.576, blue: 0.910, alpha: 1.0)
    /// Dark ink that sits on the bright tone (design `#0A0B0E`).
    static let onTone = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1.0)

    /// The active profile's tone, so the shield carries the same single accent
    /// as the session that raised it.
    private static var tone: UIColor {
        switch ActiveSessionInfo.profileName?.lowercased() {
        case "study": return UIColor(red: 0.839, green: 0.659, blue: 0.361, alpha: 1) // #D6A85C
        case "gym":   return UIColor(red: 0.498, green: 0.745, blue: 0.604, alpha: 1) // #7FBE9A
        case "sleep": return UIColor(red: 0.608, green: 0.541, blue: 0.839, alpha: 1) // #9B8AD6
        default:      return defaultTone
        }
    }

    /// The comp's ribbon, drawn into the one slot that takes a picture.
    ///
    /// iOS puts the icon above the title, which is where the comp hangs its
    /// tone-coloured ribbon with the paused app's name running down it — so the
    /// two line up. iOS owns the size it renders at and will scale the bitmap to
    /// fit its own slot; `ShieldRibbon` therefore keeps the comp's proportions
    /// (44 × 302 with an 18pt notch) rather than a fixed pixel size, and drops
    /// the name when it is too long to sit inside the drop.
    ///
    /// This replaces an earlier decision to send no icon at all. That was the
    /// right call for the comp's *timeline dot* — a bullet blown up into a large
    /// fixed slot reads as a loading spinner. A ribbon is not a dot: it has a
    /// silhouette that survives being scaled, and it is the screen's signature.
    private static func icon(subject: String?) -> UIImage? {
        ShieldRibbon.image(subject: subject, tone: tone)
    }

    /// The block screen, personalised with what is being paused (`subject` = app
    /// name or website domain, when iOS provides one).
    ///
    /// `offersSnooze` adds the comp's second button. Only apps get it: the
    /// five-minute door is per-app, and there is no sane way to open a whole
    /// category or the web for five minutes without unblocking far more than
    /// the one thing that was asked for.
    static func configuration(subject: String?, offersSnooze: Bool = false) -> ShieldConfiguration {
        let name = subject ?? "It"
        let custom = AppGroup.defaults.string(forKey: ShieldMessage.storageKey) ?? ""

        let title = ShieldConfiguration.Label(text: ShieldMessage.title(), color: primaryText)
        let subtitle = ShieldConfiguration.Label(
            text: ShieldMessage.subtitle(subject: name, custom: custom),
            color: secondaryText
        )
        let primary = ShieldConfiguration.Label(text: "Back to focus", color: onTone)

        guard offersSnooze else {
            return ShieldConfiguration(
                backgroundBlurStyle: .systemUltraThinMaterialDark,
                backgroundColor: background,
                icon: icon(subject: subject),
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: primary,
                primaryButtonBackgroundColor: tone
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: icon(subject: subject),
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primary,
            primaryButtonBackgroundColor: tone,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "I need it for 5 minutes", color: secondaryText
            )
        )
    }
}
