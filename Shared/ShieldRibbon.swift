//
//  ShieldRibbon.swift
//  Zenly (app only)
//
//  The comp's ribbon — Quiet spec, screen 03b ("Back to focus").
//
//  It used to live on the block screen and could not: `ShieldConfiguration.icon`
//  is aspect-fit into a box measured on device at roughly 80 points, and the
//  ribbon is 302 tall hanging off the top edge. A pattern-image background was
//  tried as a way round the box and does not survive the encode into iOS's
//  rendering process either.
//
//  The design has since moved it here, to the confirmation the app shows when
//  you come back from the block screen — a surface the app owns, where nothing
//  is clamped and nothing composites over it. The block screen now carries the
//  door instead (`ShieldDoor`), which is a centred glyph and fits the slot.
//
//  So this draws the comp verbatim, at the comp's own size.
//

import UIKit

enum ShieldRibbon {

    // MARK: - Geometry

    /// The comp's own geometry, for the one surface that can hold it.
    ///
    /// Transcribed verbatim:
    ///
    ///     width:44; height:302; background:var(--tone);
    ///     clip-path: polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - 18px), 0 100%);
    ///     span { writing-mode:vertical-rl; font-weight:600; font-size:10px;
    ///            letter-spacing:.34em; text-transform:uppercase;
    ///            color:#0A0B0E; padding-top:78px; }
    ///     filter: drop-shadow(0 16px 38px var(--tone-glow));
    ///
    /// Unreachable on the shield and perfectly reachable in the app, which is
    /// why the design moved it to `AppPausedView`.
    private enum Comp {
        static let width: CGFloat = 44
        static let height: CGFloat = 302
        static let notch: CGFloat = 18
        static let textInset: CGFloat = 78
        static let textSize: CGFloat = 10
        static let tracking: CGFloat = 0.34
        static let shadowPadding: CGFloat = 40
        static let shadowOffsetY: CGFloat = 16
        static let shadowBlur: CGFloat = 38
    }

    /// Width of the canvas `comp(subject:tone:)` returns — the ribbon plus the
    /// room its baked glow needs on either side.
    static var compCanvasWidth: CGFloat { Comp.width + Comp.shadowPadding * 2 }

    /// Comp `color:#0A0B0E` — the dark ink that sits on a bright tone.
    private static let onTone = UIColor(red: 0.039, green: 0.043, blue: 0.055, alpha: 1)

    // MARK: - Render

    /// The comp's ribbon at the comp's own size, for `AppPausedView`.
    ///
    /// No 100pt box here — the app owns this surface, so the geometry is the
    /// comp's verbatim, glow and all, and the name sits at the full 10pt with
    /// the comp's .34em tracking.
    static func comp(subject: String?, tone: UIColor) -> UIImage? {
        let pad = Comp.shadowPadding
        let canvas = CGSize(width: compCanvasWidth, height: Comp.height + pad)

        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false

        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let cg = context.cgContext
            let origin = CGPoint(x: pad, y: 0)

            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: Comp.shadowOffsetY),
                         blur: Comp.shadowBlur,
                         color: tone.withAlphaComponent(0.28).cgColor)
            cg.addPath(ribbonPath(at: origin, width: Comp.width,
                                  height: Comp.height, notch: Comp.notch))
            cg.setFillColor(tone.cgColor)
            cg.fillPath()
            cg.restoreGState()

            guard let name = fittingName(subject,
                                         size: Comp.textSize,
                                         tracking: Comp.tracking,
                                         available: Comp.height - Comp.textInset - Comp.notch - 8)
            else { return }
            draw(name: name, in: cg, ribbonOrigin: origin,
                 width: Comp.width, textInset: Comp.textInset)
        }
    }

    /// `polygon(0 0, 100% 0, 100% 100%, 50% calc(100% - notch), 0 100%)` — a flag
    /// with a V bitten out of the bottom edge.
    private static func ribbonPath(at origin: CGPoint,
                                   width w: CGFloat,
                                   height h: CGFloat,
                                   notch: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: origin.x, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + w, y: origin.y))
        path.addLine(to: CGPoint(x: origin.x + w, y: origin.y + h))
        path.addLine(to: CGPoint(x: origin.x + w / 2, y: origin.y + h - notch))
        path.addLine(to: CGPoint(x: origin.x, y: origin.y + h))
        path.closeSubpath()
        return path
    }

    // MARK: - The vertical name

    /// Uppercased and tracked per the comp, or nil when it will not fit inside
    /// the ribbon's drop at `size`.
    private static func fittingName(_ subject: String?,
                                    size: CGFloat,
                                    tracking: CGFloat,
                                    available: CGFloat) -> NSAttributedString? {
        let trimmed = (subject ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let attributed = NSMutableAttributedString(
            string: trimmed.uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: .semibold),
                .kern: size * tracking,
                .foregroundColor: onTone
            ])
        // Tracking is applied after every glyph including the last, which would
        // shift the run off centre. Drop it from the final character.
        if attributed.length > 0 {
            attributed.removeAttribute(.kern,
                                       range: NSRange(location: attributed.length - 1, length: 1))
        }

        guard attributed.size().width <= available else { return nil }
        return attributed
    }

    /// `writing-mode: vertical-rl` — glyphs keep their upright shape but the
    /// line runs top-to-bottom, i.e. the whole run rotated a quarter turn
    /// clockwise. Rotating the context is the same thing and keeps kerning.
    private static func draw(name: NSAttributedString,
                             in cg: CGContext,
                             ribbonOrigin: CGPoint,
                             width: CGFloat,
                             textInset: CGFloat) {
        let size = name.size()
        cg.saveGState()
        // Put the origin at the ribbon's horizontal centre, `textInset` down.
        cg.translateBy(x: ribbonOrigin.x + width / 2,
                       y: ribbonOrigin.y + textInset)
        cg.rotate(by: .pi / 2)
        // After the turn, x runs down the ribbon and y runs across it, so the
        // run is centred by offsetting half its height on the (new) y axis.
        name.draw(at: CGPoint(x: 0, y: -size.height / 2))
        cg.restoreGState()
    }
}
