//
//  AppPausedView.swift
//  Zenly
//
//  Quiet spec, screen 03b ("Back to focus") — the in-app confirmation.
//
//  Screen 03 is the block screen itself, and iOS draws that one: you tap "Back
//  to focus" there and the app you reached for closes. 03b is what Zen-ly shows
//  when you come back to it — the door at the size the comp draws it, and a
//  sentence saying the thing you reached for has been kept, not taken.
//
//      [door — 190pt seam, breathing]
//      IN SESSION · 16:12 LEFT
//      Instagram is bookmarked.
//      You'll come back to exactly this spot when the session ends.
//      Returning to your session…
//
//  No buttons. It is a receipt, not a decision — it says its piece and hands
//  you back to the timer on its own.
//
//  **This is the only surface in the flow that holds the door at all.** The
//  block screen cannot, and that is a hard limit rather than a shortfall:
//  `ShieldConfiguration.icon` is aspect-fit into a box iOS fixes at ~82 points,
//  measured twice on device, so the comp's 190pt seam arrives there at well
//  under half its height no matter what is drawn. That screen is words on black
//  now, with its icon slot left empty. Here nothing is clamped and nothing
//  composites over the background, so the comp's
//  190pt line, its 220 x 280 halo, its 9s breath, its tracked eyebrow and its
//  flat #0A0B0E all land exactly as drawn.
//
//  This replaced the ribbon, which had been standing in at this spot. The
//  ribbon still exists in `ShieldRibbon` and coming back to it is one line.
//

import SwiftUI

struct AppPausedView: View {
    /// The app or domain that was paused.
    let subject: String
    let tone: Color
    /// Time left in the session, for the comp's "16:12 left".
    let remaining: String?

    var onDismiss: () -> Void

    /// The comp's "Returning to your session…" is a promise, so it has to be
    /// kept without the user doing anything.
    private let dwell: TimeInterval = 2.6

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "0A0B0E").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                QuietDoor(tone: tone)
                    .padding(.bottom, 8)

                if let eyebrow {
                    Text(eyebrow)
                        .font(ZTheme.Font.body(11))
                        .tracking(2.42)                     // .22em at 11pt
                        .foregroundStyle(ZTheme.Palette.text(0.30))
                        .monospacedDigit()
                }

                Text("\(subject) is bookmarked.")
                    .font(ZTheme.Font.display(25, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 10)

                Text("You\u{2019}ll come back to exactly this spot when the session ends.")
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 272)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                Text("Returning to your session\u{2026}")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 40)
        }
        .contentShape(Rectangle())
        // Tapping should not be required, but waiting should not be either.
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(for: .seconds(dwell))
            onDismiss()
        }
        // `.contain` explicitly: an identifier on a container otherwise lets
        // SwiftUI fold the subtree into one element, which hides everything
        // inside it from VoiceOver's rotor as much as from the tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app-paused")
    }

    /// "IN SESSION · 16:12 LEFT".
    private var eyebrow: String? {
        guard let remaining else { return nil }
        return "IN SESSION · \(remaining) LEFT"
    }
}
