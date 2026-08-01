//
//  AppPausedView.swift
//  Zenly
//
//  Quiet spec, screen 03b ("Back to focus") — the in-app confirmation.
//
//  Screen 03 is the block screen itself, and iOS draws that one: you tap "Back
//  to focus" there and the app you reached for closes. 03b is what Zen-ly shows
//  when you come back to it — the ribbon at the size the comp draws it, and a
//  sentence saying the thing you reached for has been kept, not taken.
//
//      [ribbon, INSTAGRAM running down it]
//      IN SESSION · 16:12 LEFT
//      Instagram is bookmarked.
//      You'll come back to exactly this spot when the session ends.
//      Returning to your session…
//
//  No buttons. It is a receipt, not a decision — it says its piece and hands
//  you back to the timer on its own.
//
//  This is the surface that can hold the ribbon. The shield cannot: its icon is
//  aspect-fit into a box of about 80 points, and the ribbon is 302 tall. Here
//  nothing is clamped and nothing composites over the background, so the comp's
//  44 x 302, its .34em name, its tracked eyebrow and its flat #0A0B0E all land
//  as drawn.
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

            ribbon

            VStack(spacing: 0) {
                Spacer(minLength: 0)

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
            // The comp's text block begins below the ribbon's 302pt drop.
            .padding(.top, 220)
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

    /// The comp's ribbon at its own size — 44 x 302, hanging off the top edge,
    /// the bookmarked app's name running down it.
    @ViewBuilder
    private var ribbon: some View {
        if let image = ShieldRibbon.comp(subject: subject, tone: UIColor(tone)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: ShieldRibbon.compCanvasWidth)
                .ignoresSafeArea(edges: .top)
                .accessibilityHidden(true)
        }
    }

    /// "IN SESSION · 16:12 LEFT".
    private var eyebrow: String? {
        guard let remaining else { return nil }
        return "IN SESSION · \(remaining) LEFT"
    }
}
