//
//  LivingMotion.swift
//  Zenly
//
//  The "Living Focus" motion layer (Claude Design spec, Zenly Aurora.dc.html):
//  wave aurora ribbons, floating particles, orb pulse rings, a conic spin glow,
//  counter-orbiting sparks, and a button light-sweep. Every effect is a pure
//  transform/opacity animation (GPU-driven) and is disabled under Reduce Motion.
//

import SwiftUI

// MARK: - Wave aurora ribbon

/// A soft horizontal gradient ribbon that drifts left/right + up (zwave).
struct WaveRibbon: View {
    var colors: [Color]
    var height: CGFloat
    var yFraction: CGFloat
    var opacity: Double
    var blur: CGFloat
    var duration: Double
    var reversed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                .frame(width: geo.size.width * 1.5, height: height)
                .position(x: geo.size.width / 2, y: geo.size.height * yFraction)
                .offset(x: phase ? geo.size.width * 0.04 : -geo.size.width * 0.04,
                        y: phase ? -geo.size.height * 0.03 : 0)
                .blur(radius: blur)
                .opacity(opacity)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        phase = true
                    }
                }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Floating particles

/// Rising glowing dots. A vertical gradient mask fades them in/out by position,
/// so each dot only needs one offset animation (no per-frame work).
struct FloatingParticles: View {
    var count: Int = 6

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Spec: Identifiable {
        let id = UUID()
        let x: CGFloat        // 0...1
        let size: CGFloat
        let color: Color
        let duration: Double
        let delay: Double
    }

    private let specs: [Spec] = {
        let palette: [(Color, Color)] = [
            (ZTheme.Palette.lavenderSoft, ZTheme.Palette.violet),
            (ZTheme.Palette.brandGlow, ZTheme.Palette.brand),
            (Color(hex: "9FE9E4"), ZTheme.Palette.teal)
        ]
        return (0..<6).map { i in
            let p = palette[i % palette.count]
            return Spec(x: [0.18, 0.34, 0.58, 0.72, 0.86, 0.46][i % 6],
                        size: [5, 4, 6, 4, 5, 4][i % 6],
                        color: p.0,
                        duration: [11, 13, 12, 14, 10, 12][i % 6],
                        delay: [0, 2, 4, 1, 5, 3][i % 6])
        }
    }()

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { geo in
                ZStack {
                    ForEach(specs.prefix(count)) { spec in
                        Particle(spec: spec, area: geo.size)
                    }
                }
                .mask(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.82),
                        .init(color: .clear, location: 1.0)
                    ], startPoint: .bottom, endPoint: .top)
                )
            }
            .allowsHitTesting(false)
        }
    }

    private struct Particle: View {
        let spec: Spec
        let area: CGSize
        @State private var rise = false

        var body: some View {
            Circle()
                .fill(spec.color)
                .frame(width: spec.size, height: spec.size)
                .shadow(color: spec.color, radius: 6)
                .position(x: spec.x * area.width, y: area.height)
                .offset(y: rise ? -area.height * 1.05 : 0)
                .onAppear {
                    withAnimation(.linear(duration: spec.duration)
                        .repeatForever(autoreverses: false)
                        .delay(spec.delay)) { rise = true }
                }
        }
    }
}

// MARK: - Orb pulse rings

/// Concentric rings that expand and fade outward (zpulse), staggered.
struct PulseRings: View {
    var diameter: CGFloat
    var color: Color = Color(hex: "7C8BFF").opacity(0.5)
    var count: Int = 3
    var duration: Double = 4

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                PulseRing(diameter: diameter, color: color, duration: duration,
                          delay: Double(i) * duration / Double(count))
            }
        }
    }

    private struct PulseRing: View {
        let diameter: CGFloat
        let color: Color
        let duration: Double
        let delay: Double
        @State private var expand = false

        var body: some View {
            Circle()
                .strokeBorder(color, lineWidth: 1)
                .frame(width: diameter, height: diameter)
                .scaleEffect(expand ? 1.85 : 0.72)
                .opacity(expand ? 0 : 0.7)
                .onAppear {
                    withAnimation(.easeOut(duration: duration)
                        .repeatForever(autoreverses: false)
                        .delay(delay)) { expand = true }
                }
        }
    }
}

// MARK: - Orbiting spark

/// A glowing dot that orbits the orb's rim (zspin / zspinr).
struct OrbitingSpark: View {
    var diameter: CGFloat
    var dotSize: CGFloat
    var color: Color
    var duration: Double
    var reversed: Bool = false

    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .fill(Color.clear)
            .frame(width: diameter, height: diameter)
            .overlay(alignment: .top) {
                Circle()
                    .fill(.white)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: color, radius: dotSize * 1.4)
                    .offset(y: -dotSize / 2)
            }
            .rotationEffect(.degrees(reversed ? -angle : angle))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Conic spin glow

/// A blurred conic-gradient halo that slowly rotates behind the orb (zspin).
struct ConicSpinGlow: View {
    var diameter: CGFloat
    var duration: Double = 13
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .fill(AngularGradient(
                colors: [ZTheme.Palette.brand, ZTheme.Palette.violet, ZTheme.Palette.teal, ZTheme.Palette.brand],
                center: .center))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.13)
            .opacity(0.55)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Button light sweep

/// A diagonal highlight band that sweeps across a filled button (zsweep).
struct LivingSweep: ViewModifier {
    var duration: Double = 3.4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, .white.opacity(0.4), .clear],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * 0.46)
                        .rotationEffect(.degrees(-18))
                        .offset(x: sweep ? geo.size.width * 1.7 : -geo.size.width * 0.8)
                        .onAppear {
                            withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
                                sweep = true
                            }
                        }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func livingSweep(duration: Double = 3.4) -> some View { modifier(LivingSweep(duration: duration)) }
}

// MARK: - Shimmer text (wordmark)

/// A wordmark with a highlight that sweeps across the glyphs (zshimmer).
struct ShimmerText: View {
    var text: String
    var font: Font

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -0.4

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(ZTheme.Palette.textPrimary)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(colors: [.clear, .white.opacity(0.85), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.5)
                            .offset(x: phase * geo.size.width * 1.6)
                    }
                    .mask(Text(text).font(font))
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                            phase = 1.4
                        }
                    }
                }
            }
    }
}
