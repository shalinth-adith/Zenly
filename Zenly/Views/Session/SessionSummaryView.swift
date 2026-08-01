//
//  SessionSummaryView.swift
//  Zenly
//
//  What a finished session lands on — Quiet spec screens 04 ("Complete") and
//  04b ("Ended early").
//
//  These are two different screens, not one screen with a different adjective.
//  A completed session gets the checkmark, the total, and the streak. A session
//  ended early gets a ring showing how far it actually got, a sentence that
//  refuses to treat it as a failure, and an offer of something shorter — the
//  spec is explicit that "nothing about today is broken".
//

import SwiftUI

struct SessionSummaryView: View {
    @Environment(FocusSessionController.self) private var session
    @Environment(AchievementService.self) private var achievements
    @Environment(AnalyticsService.self) private var analytics

    @State private var newBadges: [BadgeDefinition] = []
    @State private var rating = 0

    var body: some View {
        ZStack {
            ZenlyBackground()
            if let summary = session.summary {
                // No confetti. The comp's completion screen is the quietest in
                // the set — a thin tone check on a soft halo, and the sentence
                // "A calm, unbroken session." Seventy rainbow rectangles falling
                // across it contradicts both the words underneath them and the
                // one rule the whole design runs on ("neutral throughout, a
                // single highlight"). The halo behind the check *is* the
                // celebration.
                if summary.wasCompleted {
                    completed(summary)
                } else {
                    endedEarly(summary)
                }
            }
        }
        .onAppear {
            if session.summary?.wasCompleted == true {
                newBadges = achievements.evaluate()
            }
        }
    }

    private func tone(_ summary: SessionSummary) -> Color {
        ZTheme.tone(forHex: summary.accentHex)
    }

    // MARK: - 04 · Complete

    private func completed(_ summary: SessionSummary) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(ZTheme.orbHalo(tone: tone(summary), diameter: 108))
                    .frame(width: 108, height: 108)
                CompCheck()
                    .stroke(tone(summary),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 40, height: 40)
            }
            .padding(.bottom, 30)

            Text("You focused for")
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(summary.completedMinutes)")
                    .font(ZTheme.Font.numeral(64, weight: .regular))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("min")
                    .font(ZTheme.Font.body(22))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            .padding(.top, 4)

            Text("A calm, unbroken session.")
                .font(ZTheme.Font.display(17, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .padding(.top, 20)

            Text(weekLine(summary))
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(maxWidth: 260)
                .padding(.top, 6)

            ratingDots(tone: tone(summary))
                .padding(.top, 30)

            Text("How did it feel?")
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.30))
                .padding(.top, 12)

            // At most two. The comp leaves this band empty, and a first-ever
            // session can unlock four badges at once — four stacked lines turn
            // the calmest screen in the app into a list. The rest are not lost;
            // every badge lives permanently on the Badges screen.
            ForEach(newBadges.prefix(2)) { badge in
                badgeLine(badge, tone: tone(summary))
                    .padding(.top, 16)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button("Done") {
                    session.saveReview(rating: rating, note: "")
                    session.dismissSummary()
                }
                .buttonStyle(QuietCTAStyle(tone: tone(summary), isReady: true))
                .accessibilityIdentifier("summary-done")

                Button(session.canTakeBreak ? "Take a break" : "Start another") {
                    session.saveReview(rating: rating, note: "")
                    if session.canTakeBreak {
                        session.startBreak()
                    } else {
                        session.repeatLastSession()
                    }
                }
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    // MARK: - 04b · Ended early

    private func endedEarly(_ summary: SessionSummary) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // A ring showing how far it actually got — the point of the screen
            // is that the part you did is real, so it is drawn rather than
            // described.
            ZStack {
                Circle()
                    .stroke(ZTheme.Palette.glassStroke, lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: fractionKept(summary))
                    .stroke(tone(summary),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(summary.clock)
                    .font(ZTheme.Font.numeral(26))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .accessibilityLabel(clockSpoken(summary))
                    .accessibilityIdentifier("summary-elapsed-clock")
            }
            .frame(width: 130, height: 130)
            .padding(.bottom, 34)

            Text(headline(summary))
                .font(ZTheme.Font.display(22, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .multilineTextAlignment(.center)

            Text("Some days that\u{2019}s what there is. \(keptPhrase(summary)) still count — nothing about today is broken.")
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 264)
                .padding(.top, 10)

            Text(streakLine(summary))
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.30))
                .multilineTextAlignment(.center)
                .padding(.top, 18)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button("Try a shorter one — \(shorterMinutes(summary)) min") {
                    session.dismissSummary()
                    session.repeatLastSession(minutes: shorterMinutes(summary))
                }
                .buttonStyle(QuietCTAStyle(tone: tone(summary), isReady: true))
                .accessibilityIdentifier("summary-try-shorter")

                Button("That\u{2019}s all for now") { session.dismissSummary() }
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 34)
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    // MARK: - Pieces

    /// The comp draws five 12pt dots 28pt apart. It does not draw the thing you
    /// actually have to hit.
    ///
    /// A `Shape.fill()` hit-tests against the path, so the old version — a 12pt
    /// circle with 6pt of padding — offered a 12pt target where Apple's minimum
    /// is 44. Taps on it missed often enough that the row read as decoration.
    /// The dot keeps the comp's size and spacing; only the invisible target
    /// under it grows, to 40 × 44 (40 being the pitch the comp's own spacing
    /// works out to, so the dots do not move).
    private func ratingDots(tone: Color) -> some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Button { Haptics.light(); rating = value } label: {
                    Circle()
                        .fill(value <= rating ? tone : .clear)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().strokeBorder(ZTheme.Palette.glassStroke, lineWidth: 1))
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("summary-rating-\(value)")
                .accessibilityLabel(value == 1 ? "1 out of 5" : "\(value) out of 5")
                .accessibilityAddTraits(value == rating ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(ZTheme.Motion.smooth, value: rating)
    }

    private func badgeLine(_ badge: BadgeDefinition, tone: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: badge.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(tone)
            Text(badge.title)
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))
        }
    }

    // MARK: - Copy

    /// "That's your fourth this week — the streak holds."
    private func weekLine(_ summary: SessionSummary) -> String {
        let count = analytics.calendarWeekSessionCount()
        let ordinal = Self.ordinals[min(count, Self.ordinals.count - 1)]
        let streak = summary.streak > 1 ? " — the streak holds." : "."
        return count > 0 ? "That\u{2019}s your \(ordinal) this week\(streak)"
                         : "The first of the week\(streak)"
    }

    private func headline(_ summary: SessionSummary) -> String {
        let minutes = summary.completedMinutes
        guard minutes >= 1 else { return "You made a start." }
        let spelled = Self.spelled[min(minutes, Self.spelled.count - 1)]
        return minutes <= 10 ? "You gave it \(spelled) minute\(minutes == 1 ? "" : "s")."
                             : "You gave it \(minutes) minutes."
    }

    private func keptPhrase(_ summary: SessionSummary) -> String {
        let minutes = summary.completedMinutes
        guard minutes >= 1 else { return "Starting at all does" }
        let spelled = Self.spelled[min(minutes, Self.spelled.count - 1)]
        return minutes <= 10 ? "The \(spelled) minute\(minutes == 1 ? "" : "s")"
                             : "The \(minutes) minutes"
    }

    /// "Your streak is safe · kept 4 of 5 this week"
    private func streakLine(_ summary: SessionSummary) -> String {
        let kept = analytics.calendarWeekSessionCount()
        let safe = summary.streak > 0 ? "Your streak is safe" : "Nothing lost"
        return kept > 0 ? "\(safe) · kept \(kept) this week" : safe
    }

    /// Something genuinely easier than what was just abandoned: round the time
    /// actually managed up to the nearest 5, and never suggest longer.
    private func shorterMinutes(_ summary: SessionSummary) -> Int {
        let managed = max(5, ((summary.completedMinutes + 4) / 5) * 5)
        return min(managed, max(5, summary.plannedMinutes - 5))
    }

    /// The ring is drawn from seconds, not minutes: at the short end this screen
    /// lives at, whole minutes quantise a 90-second session to the same arc as a
    /// 60-second one.
    private func fractionKept(_ summary: SessionSummary) -> Double {
        guard summary.plannedMinutes > 0 else { return 0 }
        let planned = Double(summary.plannedMinutes * 60)
        return min(1, max(0.02, Double(summary.completedSeconds) / planned))
    }

    /// VoiceOver reads "2:24" as a time of day. Say what it is.
    private func clockSpoken(_ summary: SessionSummary) -> String {
        let seconds = max(0, summary.completedSeconds)
        let m = seconds / 60, s = seconds % 60
        var parts: [String] = []
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if s > 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.isEmpty ? "Under a second focused"
                             : parts.joined(separator: " ") + " focused"
    }

    private static let ordinals = ["none", "first", "second", "third", "fourth", "fifth",
                                   "sixth", "seventh", "eighth", "ninth", "tenth", "latest"]
    private static let spelled = ["zero", "one", "two", "three", "four", "five",
                                  "six", "seven", "eight", "nine", "ten"]
}

/// The comp's checkmark, traced from it: `M13 26l8 8 16-18` on a 50-unit
/// viewBox, 3-wide round-capped stroke.
///
/// SF Symbols' `checkmark` is a different drawing — heavier, with a longer tail
/// and a tighter elbow — and at this size, alone on an otherwise empty screen,
/// the difference is the whole character of the mark. This is the one place in
/// the app worth spending a `Shape` on.
private struct CompCheck: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 50
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * s, y: rect.minY + y * s)
        }
        var path = Path()
        path.move(to: p(13, 26))
        path.addLine(to: p(21, 34))   // l8 8
        path.addLine(to: p(37, 16))   // l16 -18
        return path
    }
}
