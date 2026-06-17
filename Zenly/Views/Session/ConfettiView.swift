//
//  ConfettiView.swift
//  Zenly
//
//  Lightweight celebration confetti for the session summary. Pieces are
//  generated once (stored in state) so they don't jitter on re-render, then
//  animated from above the screen to below it.
//

import SwiftUI

struct ConfettiView: View {
    var count: Int = 70

    @State private var pieces: [Piece] = []
    @State private var fall = false

    private let colors: [Color] = [.pink, .orange, .green, .blue, .purple, .yellow, .mint]

    struct Piece: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
        let duration: Double
        let spin: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.6)
                        .position(
                            x: piece.xFraction * geo.size.width,
                            y: fall ? geo.size.height + 40 : -40
                        )
                        .rotationEffect(.degrees(fall ? piece.spin : 0))
                        .opacity(fall ? 0 : 1)
                        .animation(
                            .easeIn(duration: piece.duration).delay(piece.delay),
                            value: fall
                        )
                }
            }
            .onAppear {
                if pieces.isEmpty {
                    pieces = (0..<count).map { _ in
                        Piece(
                            xFraction: .random(in: 0...1),
                            color: colors.randomElement() ?? .blue,
                            size: .random(in: 6...11),
                            delay: .random(in: 0...0.5),
                            duration: .random(in: 1.6...3.0),
                            spin: .random(in: 180...720)
                        )
                    }
                }
                fall = true
            }
        }
        .allowsHitTesting(false)
    }
}
