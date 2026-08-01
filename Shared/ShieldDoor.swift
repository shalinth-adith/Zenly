//
//  ShieldDoor.swift
//  Zenly (shared: app + ZenlyShield)
//
//  The door — Quiet spec, screen 03 ("App paused").
//
//  A seam of light with a soft bloom behind it, which the comp draws as:
//
//      halo: 220 x 280, radial-gradient(50% 50% at 50% 50%,
//                                       var(--tone-glow), transparent 70%)
//      line: 2 x 190, radius 1,
//            linear-gradient(to bottom, transparent, var(--tone) 18%,
//                            var(--tone) 82%, transparent);
//            box-shadow: 0 0 18px 2px var(--tone-glow),
//                        0 0 60px 14px var(--tone-glow);
//
//  This replaces the ribbon that used to be here, and the replacement is what
//  makes the screen buildable at all. `ShieldConfiguration.icon` is aspect-fit
//  into a box measured on device at roughly 80 points. The ribbon hung off the
//  top edge at 302pt tall and could never fit; a door is centred and compact,
//  which is the shape the slot is.
//
//  One proportion survives intact. The comp's line is 2pt wide on a 402pt
//  screen. The icon renders at ~80pt on a ~393pt screen, so drawing the line
//  2.5pt wide inside a 100pt canvas puts it on the glass at very nearly 2pt —
//  the comp's own width. Only the height is shortened, from 190 to about 62.
//
//  The comp breathes the halo (`qglow`, 9s). A `ShieldConfiguration` icon is a
//  still image, so this is drawn at the bright end of that cycle.
//

import UIKit

enum ShieldDoor {

    private enum Metric {
        /// Square, to match the box: a taller canvas is aspect-fit *down*, so
        /// it buys height at the cost of everything else — the lesson the
        /// ribbon taught. Large, so the alignment-rect route has something to
        /// draw at if iOS honours it (see `icon(tone:)`).
        static let canvas: CGFloat = 240

        /// The layout footprint claimed via `alignmentRectInsets` — the size of
        /// the box iOS was measured to give the icon.
        static let slot: CGFloat = 82

        /// Scaled so the seam lands at ~2pt on device — the comp's own line
        /// width — whichever of the two paths iOS takes.
        static let lineWidth: CGFloat = 2.5 * (canvas / 100)

        /// Nearly the whole canvas.
        ///
        /// Measured on device: the box renders a 100pt canvas at about 82, so
        /// every canvas unit given away is a point lost off a seam that only
        /// has ~82 to work with. An earlier 78 left a fifth of the box empty
        /// and read as small. The bloom is clipped slightly at top and bottom
        /// as a result, which costs nothing — the seam has already faded to
        /// transparent by then.
        static let lineHeight: CGFloat = 96 * (canvas / 100)

        /// The comp fades transparent → tone at 18% and back out at 82%, which
        /// spends a third of the line on fade. On a 190pt line that reads as
        /// atmosphere; on a 79pt one it eats the light. Tightened so more of
        /// the seam is actually lit — the same adaptation the comp's tracking
        /// needed at small sizes.
        static let fadeStart: CGFloat = 0.12
        static let fadeEnd: CGFloat = 0.88

        /// The near bloom (comp `0 0 18px 2px`), scaled to the canvas.
        static let lineGlowBlur: CGFloat = 13 * (canvas / 100)
        /// The wide bloom (comp `0 0 60px 14px`) is what the halo below is for.
        static let haloRadius: CGFloat = 50 * (canvas / 100)
        /// Comp halo is 220 x 280 — half again as tall as it is wide.
        static let haloAspect: CGFloat = 280.0 / 220.0
    }

    /// The door, in `tone`, sized for `ShieldConfiguration.icon`.
    ///
    /// 240pt square at 2x is 480 x 480 px, under a megabyte. Size is watched
    /// here on purpose: a shield extension runs on one of the tightest memory
    /// budgets on the platform, and when it is killed for allocating too much
    /// iOS does not report it — it silently swaps in its own default screen.
    ///
    /// ## Why the canvas is 240 and not 100
    ///
    /// The slot aspect-fits into a box measured on device at ~82pt, and the
    /// comp's door is a ~190pt seam. No canvas *shape* escapes that: fitting
    /// W x H into an 82 box gives a rendered height of exactly 82 for any
    /// canvas at least as tall as it is wide, so a taller canvas only comes
    /// back narrower. That is how the old ribbon ended up 12pt across.
    ///
    /// `alignmentRectInsets` is the one mechanism left. It lets an image
    /// declare a *layout* rectangle smaller than its own bounds; a view laying
    /// out by alignment rect — which is what Auto Layout does — would give this
    /// image an 82pt slot while drawing it at 240.
    ///
    /// Whether SpringBoard's shield does that is not documented and cannot be
    /// checked from here. The important property is that being wrong costs
    /// nothing: the door is drawn filling the canvas at the comp's proportions,
    /// so if the alignment rect is ignored and the image is fit by its size, it
    /// renders at 82pt looking exactly as it did before.
    static func icon(tone: UIColor) -> UIImage? {
        let side = Metric.canvas
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        // 2x rather than 3x: the canvas is now 240pt, and 3x would be 720 x 720
        // px — over 2 MB, which is not a bet worth taking in this extension for
        // a soft-edged glow nobody will see the pixels of.
        format.scale = 2

        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                            format: format).image { context in
            let cg = context.cgContext
            let centre = CGPoint(x: side / 2, y: side / 2)

            drawHalo(in: cg, centre: centre, tone: tone)
            drawSeam(in: cg, centre: centre, tone: tone)
        }

        // Claim only the middle `slot` points as this image's layout footprint.
        let inset = (side - Metric.slot) / 2
        return image.withAlignmentRectInsets(
            UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset))
    }

    // MARK: - The bloom behind

    /// `radial-gradient(50% 50% at 50% 50%, var(--tone-glow), transparent 70%)`,
    /// on the comp's 220 x 280 ellipse.
    private static func drawHalo(in cg: CGContext, centre: CGPoint, tone: UIColor) {
        let colours = [tone.withAlphaComponent(0.28).cgColor,
                       tone.withAlphaComponent(0.16).cgColor,
                       tone.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceDeviceRGB(),
                                        colors: colours,
                                        locations: [0, 0.45, 1.0]) else { return }
        cg.saveGState()
        // Scaling the context vertically turns the radial into the comp's
        // ellipse without needing a second gradient.
        cg.translateBy(x: centre.x, y: centre.y)
        cg.scaleBy(x: 1, y: Metric.haloAspect)
        cg.drawRadialGradient(gradient,
                              startCenter: .zero, startRadius: 0,
                              endCenter: .zero, endRadius: Metric.haloRadius,
                              options: [])
        cg.restoreGState()
    }

    // MARK: - The seam of light

    /// The line itself: a 2pt round-ended bar that fades out at both ends, with
    /// the near bloom around it.
    private static func drawSeam(in cg: CGContext, centre: CGPoint, tone: UIColor) {
        let rect = CGRect(x: centre.x - Metric.lineWidth / 2,
                          y: centre.y - Metric.lineHeight / 2,
                          width: Metric.lineWidth,
                          height: Metric.lineHeight)

        // The bloom is drawn as a shadow under a solid pass, then the real
        // gradient goes on top — a gradient cannot cast a CoreGraphics shadow
        // by itself.
        cg.saveGState()
        cg.setShadow(offset: .zero, blur: Metric.lineGlowBlur,
                     color: tone.withAlphaComponent(0.55).cgColor)
        cg.setFillColor(tone.withAlphaComponent(0.9).cgColor)
        cg.addPath(CGPath(roundedRect: rect.insetBy(dx: 0, dy: rect.height * 0.12),
                          cornerWidth: Metric.lineWidth / 2,
                          cornerHeight: Metric.lineWidth / 2,
                          transform: nil))
        cg.fillPath()
        cg.restoreGState()

        // `linear-gradient(to bottom, transparent, tone 18%, tone 82%, transparent)`
        let colours = [tone.withAlphaComponent(0).cgColor,
                       tone.cgColor,
                       tone.cgColor,
                       tone.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceDeviceRGB(),
                                        colors: colours,
                                        locations: [0, Metric.fadeStart,
                                                    Metric.fadeEnd, 1.0]) else { return }
        cg.saveGState()
        cg.addPath(CGPath(roundedRect: rect,
                          cornerWidth: Metric.lineWidth / 2,
                          cornerHeight: Metric.lineWidth / 2,
                          transform: nil))
        cg.clip()
        cg.drawLinearGradient(gradient,
                              start: CGPoint(x: rect.midX, y: rect.minY),
                              end: CGPoint(x: rect.midX, y: rect.maxY),
                              options: [])
        cg.restoreGState()
    }
}

/// `CGColorSpaceCreateDeviceRGB()` under a name that reads as a value.
private func CGColorSpaceDeviceRGB() -> CGColorSpace { CGColorSpaceCreateDeviceRGB() }
