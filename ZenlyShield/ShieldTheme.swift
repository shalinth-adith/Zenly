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

    /// Design `--bg` #0A0B0E — the same near-black the app sits on.
    ///
    /// Briefly set to pure #000000 while chasing the grey surface. That was the
    /// wrong lever: the gap between #0A0B0E and #000000 is ten values out of
    /// 255, invisible under anything that lightens it and pointless if nothing
    /// does. The material is what decides this surface, so the colour goes back
    /// to being the app's own — one black across the whole product.
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

    /// The ribbon goes in the icon slot, and the background stays a flat colour.
    ///
    /// Both of those are conclusions from device testing, not first choices.
    /// See `ShieldRibbon` for the two routes to the comp's full-height ribbon
    /// and why each is closed. The short version: the icon is clamped to about
    /// 100 points square, and `UIColor(patternImage:)` does not survive being
    /// encoded across to the process that draws the shield — it arrives as
    /// nothing, leaving the screen with no background at all.

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

        // Black over the heaviest material, because it is not settled which of
        // the two actually decides this surface.
        //
        // Both fields are Optional, and `nil` for the blur may well mean "not
        // specified, use the default material" rather than "no material" — a
        // near-black `backgroundColor` came out mid-grey on device both with a
        // blur and without one, which is what that would look like. The two
        // readings have opposite fixes: if the colour is honoured and composited
        // over the material then opaque black already wins and the blur is
        // irrelevant; if it is not, the blur style is the only lever there is.
        //
        // `.dark` is the legacy heavy blur — far darker than the
        // `.systemUltraThinMaterialDark` this screen started on, which is the
        // lightest dark material Apple ships. Asking for both covers either
        // reading in one build.
        guard offersSnooze else {
            return ShieldConfiguration(
                backgroundBlurStyle: .dark,
                backgroundColor: background,
                icon: ShieldRibbon.icon(subject: subject, tone: tone),
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: primary,
                primaryButtonBackgroundColor: tone
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: background,
            icon: ShieldRibbon.icon(subject: subject, tone: tone),
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
