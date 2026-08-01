//
//  QuietDoor.swift
//  Zenly
//
//  The door from the Quiet comp, at the size it is drawn.
//
//      halo: 220 x 280, radial-gradient(50% 50% at 50% 50%,
//                                       var(--tone-glow), transparent 70%)
//      line: 2 x 190, radius 1,
//            linear-gradient(to bottom, transparent, var(--tone) 18%,
//                            var(--tone) 82%, transparent);
//            box-shadow: 0 0 18px 2px var(--tone-glow),
//                        0 0 60px 14px var(--tone-glow);
//      animation: qglow 9s ease-in-out infinite;
//
//  `ShieldDoor` draws the same door for the block screen and has to fit it in
//  an icon slot iOS fixes at ~82 points, so it loses three-fifths of its height
//  and compensates with a heavier line. Nothing is clamped here. Every number
//  above is the comp's own, and the drawing is vectors rather than a bitmap, so
//  it is sharp at any size and the halo can breathe the way the comp does — the
//  one thing a `ShieldConfiguration` icon could never do, being a still image.
//
//  `height` scales the whole drawing about the seam, so the comp's proportions
//  hold wherever it is placed.
//

import SwiftUI

struct QuietDoor: View {
    var tone: Color
    /// The seam's length. The comp draws 190; everything else is derived.
    var height: CGFloat = 190
    /// The comp's 9s `qglow`. Off for a still capture.
    var isBreathing: Bool = true

    /// Honoured explicitly: a slow pulse behind text is exactly the kind of
    /// motion that Reduce Motion exists to stop.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isOpen = false

    /// Comp ratios, all against the 190pt line.
    private var scale: CGFloat { height / 190 }
    private var lineWidth: CGFloat { 2 * scale }
    private var haloWidth: CGFloat { 220 * scale }
    private var haloHeight: CGFloat { 280 * scale }

    private var breathes: Bool { isBreathing && !reduceMotion }

    var body: some View {
        ZStack {
            halo
            seam
        }
        .frame(width: haloWidth, height: haloHeight)
        .onAppear {
            guard breathes else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                isOpen = true
            }
        }
        .accessibilityHidden(true)
    }

    /// `radial-gradient(..., var(--tone-glow), transparent 70%)` on the comp's
    /// 220 x 280 ellipse. Drawn as an ellipse rather than a scaled circle so the
    /// gradient stays true at the edges.
    private var halo: some View {
        Ellipse()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: tone.opacity(0.30), location: 0),
                        .init(color: tone.opacity(0.16), location: 0.42),
                        .init(color: tone.opacity(0), location: 0.72)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: haloHeight / 2
                )
            )
            .scaleEffect(isOpen ? 1.06 : 0.97)
            .opacity(isOpen ? 1.0 : 0.72)
    }

    /// The seam, with the comp's two blooms around it.
    ///
    /// SwiftUI's `.shadow` does not stack the way CSS's comma-separated
    /// `box-shadow` does — a second modifier shadows the *result* of the first,
    /// which smears rather than deepens. So the two blooms are drawn as two
    /// blurred copies of the seam behind the sharp one, which is what the comp's
    /// `0 0 18px` and `0 0 60px` actually look like.
    private var seam: some View {
        ZStack {
            line.blur(radius: 30 * scale).opacity(0.55)   // 0 0 60px 14px
            line.blur(radius: 9 * scale).opacity(0.85)    // 0 0 18px 2px
            line
        }
        .opacity(isOpen ? 1.0 : 0.86)
    }

    private var line: some View {
        Capsule()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: tone.opacity(0), location: 0),
                        .init(color: tone, location: 0.18),
                        .init(color: tone, location: 0.82),
                        .init(color: tone.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: lineWidth, height: height)
    }
}

#Preview {
    ZStack {
        Color(hex: "0A0B0E").ignoresSafeArea()
        QuietDoor(tone: Color(hex: "7C93E8"))
    }
}
