//
//  ShieldRibbon.swift
//  Zenly (shared: app + ZenlyShield)
//
//  The comp's ribbon, redrawn for the only space iOS will give it — Quiet spec,
//  screen 03 ("App paused").
//
//  The comp hangs a 44 x 302 tone ribbon off the top edge of the screen. That
//  cannot be built. `ShieldConfiguration` is a fixed set of slots — background
//  colour, blur style, one image, a title, a subtitle, two buttons — encoded and
//  sent to another process, where iOS lays them out on metrics it does not
//  publish. Both routes to the comp's geometry were tried on device and both are
//  closed:
//
//  1. **The icon slot** aspect-fits into a box of roughly 100 x 100 points. A
//     302pt ribbon came back 94pt tall and 34 wide, its name reduced to texture.
//     No aspect ratio escapes the box; the comp's ribbon is three times taller
//     than the whole slot.
//
//  2. **A pattern-image background** (`UIColor(patternImage:)`) is not clamped by
//     any slot, but does not survive the trip. `UIColor` encodes as colour-space
//     components; a pattern image has no representation in that, so it arrives
//     as nothing and the shield renders with no background at all.
//
//  So the ribbon is drawn for a 100pt square instead — as large inside that box
//  as it can be. What survives from the comp is what matters: the silhouette,
//  the notch, the tone, the name running down it, and roughly the comp's
//  proportion of the screen's width (the comp's ribbon is 44 of 402 points
//  across, about 11%; this one lands near 9%). What is lost is the drop, and
//  nothing can buy it back short of Apple opening the shield to custom views.
//

import UIKit

enum ShieldRibbon {

    // MARK: - Geometry

    /// iOS aspect-fits the icon into a box measured on device at roughly
    /// 100 x 100 points. A square canvas means none of it is wasted — the
    /// earlier tall canvas spent most of the box on empty margin, which is why
    /// the ribbon came back so thin.
    private enum Metric {
        static let canvas: CGFloat = 100

        /// Comp ratio: 44 of 402 screen points. Against a ~100pt slot on a
        /// ~393pt screen, 34 lands at about the same share of the width.
        static let width: CGFloat = 34
        /// Everything but the room the glow needs underneath.
        static let height: CGFloat = 92
        /// The comp's V, scaled to the shorter tail.
        static let notch: CGFloat = 8
        /// Where the name starts down the ribbon (comp: 78 of 302, ~26%).
        static let textInset: CGFloat = 14
        /// As large as fits the shortened drop. The comp's 10pt would push a
        /// nine-letter name past the notch.
        static let textSize: CGFloat = 8
        /// Tightened from the comp's .34em for the same reason.
        static let tracking: CGFloat = 0.18

        static let glowOffsetY: CGFloat = 3
        static let glowBlur: CGFloat = 6
    }

    /// Comp `color:#0A0B0E` — the dark ink that sits on a bright tone.
    private static let onTone = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1)

    // MARK: - Render

    /// The ribbon, in `tone`, with `subject` (the app name or domain) running
    /// down it, sized for `ShieldConfiguration.icon`.
    ///
    /// `subject` is dropped when it will not fit the drop at a legible size —
    /// a name squeezed or clipped reads as a rendering fault, and the subtitle
    /// names the app anyway. The ribbon alone still carries the screen.
    ///
    /// Rendered at 3x into a 100pt square: 300 x 300 px, about 360 KB. Worth
    /// stating, because the previous version rendered a screen-sized bitmap at
    /// device scale — 12 MB, and roughly double at peak — and a ManagedSettingsUI
    /// extension runs on one of the tightest memory budgets on the platform. It
    /// was killed for it, and a killed shield extension is not reported: iOS
    /// silently substitutes its own default screen.
    static func icon(subject: String?, tone: UIColor) -> UIImage? {
        let side = Metric.canvas
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = 3

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                       format: format).image { context in
            let cg = context.cgContext
            let origin = CGPoint(x: (side - Metric.width) / 2, y: 0)

            // The comp's `filter: drop-shadow(0 16px 38px var(--tone-glow))`,
            // scaled down with the ribbon. --tone-glow is the tone at 0.28.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: Metric.glowOffsetY),
                         blur: Metric.glowBlur,
                         color: tone.withAlphaComponent(0.28).cgColor)
            cg.addPath(ribbonPath(at: origin))
            cg.setFillColor(tone.cgColor)
            cg.fillPath()
            cg.restoreGState()

            guard let name = fittingName(subject) else { return }
            draw(name: name, in: cg, ribbonOrigin: origin)
        }
    }

    /// `polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - notch), 0 100%)` — a flag
    /// with a V bitten out of the bottom edge.
    private static func ribbonPath(at origin: CGPoint) -> CGPath {
        let w = Metric.width, h = Metric.height
        let path = CGMutablePath()
        path.move(to: CGPoint(x: origin.x, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + w, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + w, y: origin.y + h))
        path.addLine(to: CGPoint(x: origin.x + w / 2, y: origin.y + h - Metric.notch))
        path.addLine(to: CGPoint(x: origin.x, y: origin.y + h))
        path.closeSubpath()
        return path
    }

    // MARK: - The vertical name

    /// Uppercased and tracked per the comp, or nil when it will not fit inside
    /// the ribbon's drop.
    private static func fittingName(_ subject: String?) -> NSAttributedString? {
        let trimmed = (subject ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let attributed = NSMutableAttributedString(
            string: trimmed.uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: Metric.textSize, weight: .semibold),
                .kern: Metric.textSize * Metric.tracking,
                .foregroundColor: onTone
            ])
        // Tracking is applied after every glyph including the last, which would
        // shift the run off centre. Drop it from the final character.
        if attributed.length > 0 {
            attributed.removeAttribute(.kern,
                                       range: NSRange(location: attributed.length - 1, length: 1))
        }

        // The name runs from `textInset` to the top of the notch.
        let available = Metric.height - Metric.textInset - Metric.notch - 3
        guard attributed.size().width <= available else { return nil }
        return attributed
    }

    /// `writing-mode: vertical-rl` — glyphs keep their upright shape but the
    /// line runs top-to-bottom, i.e. the whole run rotated a quarter turn
    /// clockwise. Rotating the context is the same thing and keeps kerning.
    private static func draw(name: NSAttributedString,
                             in cg: CGContext,
                             ribbonOrigin: CGPoint) {
        let size = name.size()
        cg.saveGState()
        // Put the origin at the ribbon's horizontal centre, `textInset` down.
        cg.translateBy(x: ribbonOrigin.x + Metric.width / 2,
                       y: ribbonOrigin.y + Metric.textInset)
        cg.rotate(by: .pi / 2)
        // After the turn, x runs down the ribbon and y runs across it, so the
        // run is centred by offsetting half its height on the (new) y axis.
        name.draw(at: CGPoint(x: 0, y: -size.height / 2))
        cg.restoreGState()
    }
}
