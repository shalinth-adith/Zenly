//
//  BlockScreenPreview.swift
//  Zenly
//
//  A DEBUG-only look at the block screen (Quiet spec, screen 03).
//
//  iOS draws the real one, inside the ZenlyShield extension, and only when a
//  Screen Time shield is up — which Simulator will never allow. So this puts the
//  extension's own inputs on screen: the same `ShieldMessage` strings and the
//  same button labels, with no icon, because the shield now sends none.
//
//  Laid out the way iOS stacks the slots — title, subtitle, buttons — rather
//  than the way the comp does, because this gets screenshot as evidence and a
//  preview of something that cannot ship is worse than no preview. The spacing
//  is still approximate; iOS's real metrics are private. What it proves is
//  every word.
//
//  Two gates: compiled out of Release, and only reachable with the launch
//  argument.
//

#if DEBUG

import SwiftUI

struct BlockScreenPreview: View {
    var subject: String
    var tone: Color

    var body: some View {
        ZStack {
            // The shield surface renders near #242424 on device, not this — iOS
            // paints `backgroundColor` at ~17% over a surface of its own. Drawn
            // here as the value we send, not the value that lands.
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text(ShieldMessage.title(subject: subject))
                    .font(ZTheme.Font.display(25, weight: .semibold))
                    .foregroundStyle(Color(hex: "E7E8EC"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)

                Text(ShieldMessage.subtitle(custom: ""))
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    Text("Back to focus")
                        .font(ZTheme.Font.display(16, weight: .semibold))
                        .foregroundStyle(Color(hex: "0A0B0E"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(tone, in: Capsule())
                    Text("I need it for 5 minutes")
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("block-screen-preview")
    }
}

#endif
