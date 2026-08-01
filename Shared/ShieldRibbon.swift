//
//  ShieldRibbon.swift
//  Zenly (shared: app + ZenlyShield)
//
//  The one piece of the block screen's geometry that iOS will actually let us
//  draw — Quiet spec, screen 03 ("App paused").
//
//  `ShieldConfiguration` is a fixed set of slots (background, blur, one image, a
//  title, a subtitle, two buttons) laid out by iOS in its own process. We cannot
//  place a view. But the comp's dominant mark is a tone-coloured ribbon hanging
//  from the top edge with the paused app's name running down it, and a ribbon is
//  a picture — so it goes in the one slot that takes a picture.
//
//  Geometry is transcribed from the comp verbatim:
//
//      width:44; height:302; background:var(--tone);
//      clip-path: polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - 18px), 0 100%);
//      span { writing-mode:vertical-rl; font-weight:600; font-size:10px;
//             letter-spacing:.34em; text-transform:uppercase;
//             color:#0A0B0E; padding-top:78px; }
//
//  The drop shadow the comp puts under it (`0 16px 38px var(--tone-glow)`) is
//  baked into the bitmap rather than left to the host, since we do not control
//  the layer it lands on.
//

import UIKit

enum ShieldRibbon {

    // MARK: - Comp geometry

    private enum Metric {
        /// Comp `width:44`.
        static let width: CGFloat = 44
        /// Comp `height:302`.
        static let height: CGFloat = 302
        /// Comp `calc(100% - 18px)` — how far the V bites up into the tail.
        static let notch: CGFloat = 18
        /// Comp `padding-top:78px` — where the name starts down the ribbon.
        static let textInset: CGFloat = 78
        /// Comp `font-size:10px`.
        static let textSize: CGFloat = 10
        /// Comp `letter-spacing:.34em`.
        static let tracking: CGFloat = 0.34
        /// Room the baked shadow needs around the shape (`0 16px 38px`).
        static let shadowPadding: CGFloat = 40
        static let shadowOffsetY: CGFloat = 16
        static let shadowBlur: CGFloat = 38
    }

    /// Comp `color:#0A0B0E` — the dark ink that sits on a bright tone.
    private static let onTone = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1)

    /// Design `--bg` #0A0B0E — the surface the ribbon hangs on.
    private static let canvasColor = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1)

    /// A safe default when the extension cannot read a screen size. iPhone 15 /
    /// 16 / 17 logical points; being wrong here only moves the ribbon off
    /// centre by a few points, because the pattern is anchored top-left.
    private static let fallbackScreen = CGSize(width: 393, height: 852)

    // MARK: - Render

    /// The whole shield surface: `--bg`, with the ribbon hanging from the top
    /// edge at the comp's own 44 × 302, `subject` running down it.
    ///
    /// This goes in `ShieldConfiguration.backgroundColor` via
    /// `UIColor(patternImage:)`, not in the icon slot.
    ///
    /// The icon slot looked like the obvious home for it and is not. iOS
    /// aspect-fits whatever it is handed into a box of about 100 × 100 points,
    /// so a 302pt ribbon came back 94pt tall and 34 wide, with the app's name
    /// scaled down to illegible texture. The background has no such box: it is
    /// the full surface, so the ribbon can be exactly the size the comp draws
    /// it, in the position the comp draws it.
    ///
    /// Sized to the whole screen so the pattern never visibly repeats.
    static func backdrop(subject: String?, tone: UIColor, screen: CGSize? = nil) -> UIImage? {
        let size = screen ?? currentScreenSize()
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext

            cg.setFillColor(canvasColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            // Comp: `left:50%; top:0; transform:translateX(-50%)`.
            let origin = CGPoint(x: (size.width - Metric.width) / 2, y: 0)

            // The comp's `filter: drop-shadow(0 16px 38px var(--tone-glow))`.
            // --tone-glow is the tone at 0.28.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: Metric.shadowOffsetY),
                         blur: Metric.shadowBlur,
                         color: tone.withAlphaComponent(0.28).cgColor)
            cg.addPath(ribbonPath(at: origin))
            cg.setFillColor(tone.cgColor)
            cg.fillPath()
            cg.restoreGState()

            guard let name = fittingName(subject) else { return }
            draw(name: name, in: cg, ribbonOrigin: origin)
        }
    }

    /// A transparent image of the size iOS gives the icon slot.
    ///
    /// iOS lays the shield out as a stack — icon, then title, then subtitle —
    /// so passing no icon pulls the title up the screen and into the ribbon.
    /// This holds the title where the comp has it while drawing nothing. There
    /// is no spacing control in `ShieldConfiguration`; occupying the slot is
    /// the only lever there is.
    static func titleSpacer() -> UIImage? {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100),
                                       format: format).image { _ in }
    }

    /// Logical screen size, read without a window scene.
    ///
    /// A `ShieldConfigurationDataSource` is not a view controller and has no
    /// scene to ask, so `UIScreen.main` is the only thing available — soft
    /// deprecated, still the sole answer inside this kind of extension.
    private static func currentScreenSize() -> CGSize {
        let bounds = UIScreen.main.bounds.size
        return bounds.width > 0 ? bounds : fallbackScreen
    }

    /// `polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - 18px), 0 100%)` — a flag
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
        // Tracking is applied *after* every glyph including the last, which
        // would shift the run off centre. Drop it from the final character.
        if attributed.length > 0 {
            attributed.removeAttribute(.kern,
                                       range: NSRange(location: attributed.length - 1, length: 1))
        }

        // The name runs from `textInset` to the top of the notch.
        let available = Metric.height - Metric.textInset - Metric.notch - 8
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
