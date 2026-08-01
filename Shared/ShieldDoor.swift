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
//  The height is not ours to set — the slot is ~82pt and nothing in
//  `ShieldConfiguration` changes that, which `icon(tone:)` records in full. So
//  the drawing is scaled the way a smaller reproduction has to be, rather than
//  reduced uniformly: the seam runs the whole canvas, and both the line and its
//  bloom are opened up past the comp's literal values. A 2pt line reads as a
//  door at 190 tall and as a hairline at 82. Holding the number would have been
//  faithful to the spec and wrong on the glass.
//
//  The comp breathes the halo (`qglow`, 9s). A `ShieldConfiguration` icon is a
//  still image, so this is drawn at the bright end of that cycle.
//

import UIKit

enum ShieldDoor {

    private enum Metric {
        /// Square, to match the box: a taller canvas is aspect-fit *down*, so
        /// it buys height at the cost of everything else — the lesson the
        /// ribbon taught.
        ///
        /// Sized to roughly what the box renders. Briefly 240, to give
        /// `alignmentRectInsets` something large to draw at — see the note on
        /// `icon(tone:)`. That did nothing, so the canvas comes back down: at
        /// 240 the bitmap was 480 x 480 px for a picture that lands at 82pt,
        /// and this extension is killed silently for allocating too much.
        static let canvas: CGFloat = 100

        /// Lands at ~3.8pt on device once the box scales the canvas to ~82.
        ///
        /// The comp draws 2pt — but it draws it 190 tall. Held to 2pt at a
        /// quarter of that height the seam reads as a hairline rather than a
        /// door, because a line's presence is its area and this one has lost
        /// three-fifths of its length. Widening it back is the only dimension
        /// still ours to spend, so it is spent here.
        ///
        /// Went 2.5 → 3.4 → 4.6. The middle step was invisible on the glass,
        /// which is its own lesson: a fifth of a point of extra width is not
        /// something an eye can find on a seam this short. Small increments
        /// waste a build; at this size the drawing has to commit.
        static let lineWidth: CGFloat = 4.6 * (canvas / 100)

        /// The whole canvas.
        ///
        /// Measured on device: the box renders a 100pt canvas at about 82, so
        /// every canvas unit given away is a point lost off a seam that only
        /// has ~82 to work with. An earlier 78 left a fifth of the box empty
        /// and read as small; 96 still left a margin worth ~3pt. The ends of
        /// the seam have already faded to transparent, so running it edge to
        /// edge costs nothing and shows no cut.
        static let lineHeight: CGFloat = canvas

        /// The comp fades transparent → tone at 18% and back out at 82%, which
        /// spends a third of the line on fade. On a 190pt line that reads as
        /// atmosphere; on a 79pt one it eats the light. Tightened so more of
        /// the seam is actually lit — the same adaptation the comp's tracking
        /// needed at small sizes.
        static let fadeStart: CGFloat = 0.12
        static let fadeEnd: CGFloat = 0.88

        /// The near bloom (comp `0 0 18px 2px`), scaled to the canvas and then
        /// opened up — same reasoning as `lineWidth`. Light spilling off the
        /// seam is the other half of how big the door looks.
        static let lineGlowBlur: CGFloat = 22 * (canvas / 100)
        /// The wide bloom (comp `0 0 60px 14px`) is what the halo below is for.
        ///
        /// The comp's halo is 280 tall against a 190 line — half again the
        /// seam's own length, so it was always going to overrun the canvas.
        /// It is meant to; see `drawHalo` for how the cut is kept invisible.
        static let haloRadius: CGFloat = 54 * (canvas / 100)
        /// Comp halo is 220 x 280 — half again as tall as it is wide.
        static let haloAspect: CGFloat = 280.0 / 220.0
    }

    /// The door, in `tone`, sized for `ShieldConfiguration.icon`.
    ///
    /// 100pt square at 3x is 300 x 300 px, about 360 KB. Size is watched here
    /// on purpose: a shield extension runs on one of the tightest memory
    /// budgets on the platform, and when it is killed for allocating too much
    /// iOS does not report it — it silently swaps in its own default screen.
    ///
    /// ## The door renders at ~82pt and cannot be made taller
    ///
    /// Settled on device, not assumed. Three things were tried and all three
    /// are dead ends:
    ///
    /// 1. **A taller canvas.** Aspect-fitting W x H into an 82pt box gives a
    ///    rendered height of exactly 82 for *any* canvas at least as tall as it
    ///    is wide — the canvas height cancels out. Extra height only comes back
    ///    as lost width, which is how the old ribbon ended up 12pt across.
    /// 2. **A pattern-image background** to escape the slot entirely.
    ///    `UIColor` encodes as colour-space components, so the pattern arrives
    ///    at iOS's rendering process as nothing at all.
    /// 3. **`alignmentRectInsets`**, declaring a layout rect smaller than the
    ///    image so a host laying out by alignment rect would draw it larger.
    ///    Shipped at a 240pt canvas claiming an 82pt footprint; the device
    ///    rendered it at exactly the same size as before. SpringBoard's shield
    ///    does not lay out that way.
    ///
    /// The comp's seam is ~190pt. This one is ~79. The gap is not a shortfall
    /// in the drawing — it is the size of the slot, and the slot is not a
    /// parameter. It would take Apple accepting a view here, the way WidgetKit
    /// and Live Activities do.
    static func icon(tone: UIColor) -> UIImage? {
        let side = Metric.canvas
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = 3

        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side),
                                       format: format).image { context in
            let cg = context.cgContext
            let centre = CGPoint(x: side / 2, y: side / 2)

            drawHalo(in: cg, centre: centre, tone: tone)
            drawSeam(in: cg, centre: centre, tone: tone)
        }
    }

    // MARK: - The bloom behind

    /// `radial-gradient(50% 50% at 50% 50%, var(--tone-glow), transparent 70%)`,
    /// on the comp's 220 x 280 ellipse.
    ///
    /// Four stops rather than three, and the reason is the clip. The ellipse is
    /// taller than the canvas by design, so the renderer cuts it at the top and
    /// bottom edges — and a radial gradient cut while it still has alpha left
    /// shows a straight line, which turns a bloom into a rectangle. The extra
    /// stop at 0.72 pulls the falloff in so the gradient is down to about 5%
    /// by the time it reaches the edge, where the cut cannot be seen.
    private static func drawHalo(in cg: CGContext, centre: CGPoint, tone: UIColor) {
        let colours = [tone.withAlphaComponent(0.58).cgColor,
                       tone.withAlphaComponent(0.34).cgColor,
                       tone.withAlphaComponent(0.07).cgColor,
                       tone.withAlphaComponent(0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceDeviceRGB(),
                                        colors: colours,
                                        locations: [0, 0.35, 0.72, 1.0]) else { return }
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
                     color: tone.withAlphaComponent(0.88).cgColor)
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
