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

    /// The comp's ribbon, painted onto the whole surface rather than dropped
    /// into the icon slot.
    ///
    /// The icon slot was the obvious home for it and does not work. iOS
    /// aspect-fits the icon into a box of roughly 100 × 100 points, so the
    /// comp's 44 × 302 ribbon came back about 34 × 94 on device, with the app's
    /// name scaled down to illegible texture. None of that is adjustable — the
    /// box is iOS's, and the comp's ribbon is three times taller than the whole
    /// slot.
    ///
    /// `backgroundColor` has no such box. A `UIColor(patternImage:)` sized to
    /// the screen paints the entire shield, so the ribbon lands at exactly the
    /// comp's size, hanging off the top edge exactly where the comp hangs it.
    ///
    /// Falls back to the flat background if the backdrop cannot be rendered: a
    /// shield that comes up plain is survivable, one that comes up blank is not.
    private static func backgroundColor(subject: String?) -> UIColor {
        // Drop the intermediates as soon as the pattern owns the bitmap. Peak
        // memory, not steady state, is what gets an extension killed.
        autoreleasepool {
            guard let backdrop = ShieldRibbon.backdrop(subject: subject, tone: tone) else {
                return background
            }
            return UIColor(patternImage: backdrop)
        }
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

        // No blur: the backdrop is opaque and carries the ribbon, and a blur
        // layer over it only gives the compositor a chance to wash the tone out.
        //
        // The icon is a transparent spacer. iOS stacks icon → title → subtitle,
        // so sending none pulls the title up under the ribbon; the spacer holds
        // it where the comp has it while drawing nothing. There is no spacing
        // control in `ShieldConfiguration` — occupying the slot is the only
        // lever it gives you.
        guard offersSnooze else {
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
                backgroundColor: backgroundColor(subject: subject),
                icon: ShieldRibbon.titleSpacer(),
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: primary,
                primaryButtonBackgroundColor: tone
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: backgroundColor(subject: subject),
            icon: ShieldRibbon.titleSpacer(),
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
