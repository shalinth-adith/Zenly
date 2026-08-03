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
    /// It will not render as #0A0B0E, and that is not something left undone.
    ///
    /// The shield surface refused to go black through several rounds, so it was
    /// measured rather than guessed at: a build sending pure red (255, 0, 0)
    /// came back as roughly (78, 34, 34) on device. Solving that composite —
    ///
    ///     result = ours × a + base × (1 − a)
    ///     green:    0 × a + base × (1 − a) = 34
    ///     red:    255 × a + 34             = 78   →   a ≈ 0.173
    ///                                              →   base ≈ #292929
    ///
    /// — says iOS paints `backgroundColor` at about **17% opacity** over a
    /// ~#292929 surface of its own. The model predicts this colour lands at
    /// #242424, which is exactly what a device photo of the shield measured
    /// before the diagnostic was ever run.
    ///
    /// So the floor is #222222, and pure black is the only colour that reaches
    /// it. The design's own #0A0B0E lands at #242424 — two values higher out of
    /// 255, which nobody can see, but there is no reason to give them away on
    /// the one surface in the product that cannot render its colour properly.
    /// Black is what goes here, and #0A0B0E stays everywhere else.
    ///
    /// The comp's flat #0A0B0E version of this screen exists in `AppPausedView`,
    /// where nothing composites over it and the colour renders as drawn.
    static let background = UIColor.black

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

    /// The block screen, personalised with what is being paused (`subject` = app
    /// name or website domain, when iOS provides one).
    ///
    /// One button. There was a second — "I need it for 5 minutes" — and it is
    /// gone, because Screen Time cannot support it where it mattered.
    ///
    /// The pass has to name the app it lets through, and the only thing
    /// `shield.applicationCategories = .all(except:)` accepts is an
    /// `ApplicationToken`. Measured on device (iOS 26.6): when a shield comes
    /// from a category — which is what "Block everything" builds, and what all
    /// four default profiles use — this extension is handed the app's name and
    /// bundle identifier but NOT its token. A bundle identifier cannot be
    /// converted into one; tokens are minted by the system from a
    /// `FamilyActivitySelection` and nowhere else.
    ///
    /// So the door could only ever have worked for the minority of profiles
    /// that block a hand-picked list of apps, and was a dead control on every
    /// other block screen. A button that closes the app and changes nothing is
    /// worse than no button.
    static func configuration(subject: String?) -> ShieldConfiguration {
        let name = subject ?? "It"
        let custom = AppGroup.defaults.string(forKey: ShieldMessage.storageKey) ?? ""

        let title = ShieldConfiguration.Label(text: ShieldMessage.title(subject: name),
                                              color: primaryText)
        let subtitle = ShieldConfiguration.Label(
            text: ShieldMessage.subtitle(custom: custom),
            color: secondaryText
        )
        let primary = ShieldConfiguration.Label(text: "Back to focus", color: onTone)

        // No icon. The words carry the screen on their own.
        //
        // The comp draws a door here — a 190pt seam of light. It cannot be
        // drawn: `ShieldConfiguration.icon` is aspect-fit into a box fixed at
        // ~82 points, measured twice on device (the old 44 x 302 ribbon came
        // back 12 x 82, which pins the box height by itself). At 82 the seam is
        // an ornament rather than a door, and three rounds of thickening and
        // brightening it did not change that — the gap was always height.
        //
        // A quarter-scale version of a design's centrepiece reads as a mistake.
        // Nothing reads as restraint, which is what the screen is about. The
        // full-size door lives in `QuietDoor`, on a surface the app owns.
        //
        // No blur: it changes nothing here and fewer moving parts is worth more
        // than a style name. The measured composite (see `background`) shows
        // iOS painting our colour at ~17% over a surface of its own, and every
        // style from `.systemUltraThinMaterialDark` to `.dark` landed on the
        // same grey.
        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: background,
            icon: nil,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primary,
            primaryButtonBackgroundColor: tone
        )
    }
}
