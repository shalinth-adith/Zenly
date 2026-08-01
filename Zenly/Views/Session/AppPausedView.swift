//
//  AppPausedView.swift
//  Zenly
//
//  Quiet spec, screen 03 ("App paused") — the comp, at the size it was drawn.
//
//  This is not the block screen. The block screen is drawn by iOS from a
//  `ShieldConfiguration`, and the comp cannot be built there: nine primitive
//  fields, laid out in another process, with the icon clamped to an ~80pt box
//  against the comp's 302pt ribbon. `ShieldRibbon` documents the routes tried
//  and why each is closed.
//
//  So the comp lives here instead, on the one surface the app owns — shown when
//  you come back to Zen-ly during a session and a shield stood in front of
//  something in the last few minutes. Everything the shield had to give up is
//  here: the ribbon at a full 44 x 302 hanging off the top edge, the tracked
//  eyebrow above the headline rather than folded into the subtitle, the comp's
//  exact type scale, and a flat `--bg` surface with nothing composited over it.
//
//  Both actions are real. "Back to focus" dismisses; "I need it for 5 minutes"
//  opens the same five-minute door the shield's own button does, through the
//  same `SnoozeStore`, using the token the shield recorded.
//

import SwiftUI
import ManagedSettings

struct AppPausedView: View {
    /// The app or domain that was paused.
    let subject: String
    /// When the shield went up — the comp's "Back at 7:43" counts from the
    /// session's end, not from this.
    let tone: Color
    /// When the quiet ends, or nil if nothing is running.
    let endsAt: Date?

    var onDismiss: () -> Void
    var onSnooze: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            // Comp `--bg`, flat. No material, no blur — the thing the real
            // shield could not have.
            Color(hex: "0A0B0E").ignoresSafeArea()

            ribbon

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // The comp's eyebrow, in its own place above the headline. On
                // the shield this had to be folded into the subtitle, because
                // `ShieldConfiguration.Label` is a String and a colour and
                // there is no third slot to put it in.
                if let returnLine {
                    Text(returnLine)
                        .font(ZTheme.Font.body(11))
                        .tracking(2.42)                     // .22em at 11pt
                        .foregroundStyle(ZTheme.Palette.text(0.30))
                        .monospacedDigit()
                }

                Text("Your place is kept.")
                    .font(ZTheme.Font.display(25, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 10)

                Text("\(subject) waits exactly as you left it — same place, same scroll.\(minutesTail)")
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 272)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Button("Back to focus") { Haptics.light(); onDismiss() }
                        .buttonStyle(QuietCTAStyle(tone: tone, isReady: true))
                        .accessibilityIdentifier("paused-back-to-focus")

                    if let onSnooze {
                        Button("I need it for 5 minutes") { Haptics.light(); onSnooze() }
                            .font(ZTheme.Font.body(14))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("paused-five-minutes")
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            // Comp: the text block begins below the ribbon's 302pt drop.
            .padding(.top, 220)
        }
        // `.contain` explicitly: an identifier on a container otherwise lets
        // SwiftUI fold the subtree into one element, which hides the two
        // buttons from anything querying by identifier — VoiceOver's rotor and
        // the UI tests alike.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app-paused")
    }

    /// The comp's ribbon at its own size — 44 x 302, hanging off the top edge,
    /// the paused app's name running down it.
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

    /// "BACK AT 7:43".
    private var returnLine: String? {
        guard let endsAt, endsAt > Date() else { return nil }
        let clock = DateFormatter()
        clock.locale = .autoupdatingCurrent
        clock.setLocalizedDateFormatFromTemplate("jm")
        return "BACK AT \(clock.string(from: endsAt))"
    }

    /// The comp closes the paragraph with the time left ("16 minutes.").
    private var minutesTail: String {
        guard let minutes = ActiveSessionInfo.remainingMinutes else { return "" }
        return minutes == 1 ? " 1 minute." : " \(minutes) minutes."
    }
}
