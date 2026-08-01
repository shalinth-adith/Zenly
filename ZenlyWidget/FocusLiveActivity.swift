//
//  FocusLiveActivity.swift
//  ZenlyWidget
//
//  Live Activity for the focus session — the Quiet spec's screens 14 and 15
//  (Zenly Quiet.dc.html: "Lock screen" and "Live activity · every state").
//
//  The card is a single quiet panel: the profile name and the finish time in
//  small tracked caps, one thin countdown, a plain sentence beside it, and a
//  2pt rule across the bottom carrying the progress. Four states, each a small
//  departure from that one shape:
//
//    Under way    — neutral panel, the tone only in the progress rule
//    Last stretch — panel warms to the tone, numerals lighten, copy changes
//    Paused       — everything dims, the rule empties, a Resume button appears
//    Finished     — the rule fills solid, the numeral is what was kept, "Again"
//
//  Dynamic Island compact is deliberately one dot and one number: no app name,
//  no icon, nothing to read twice.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenCard(context: context)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(Color(hex: context.attributes.accentHex))
        } dynamicIsland: { context in
            let tone = Color(hex: context.attributes.accentHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.profileName.uppercased())
                        .font(.system(size: 11))
                        .tracking(2.4)
                        .foregroundStyle(.white.opacity(0.45))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Island.trailing(context))
                        .font(.system(size: 11))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.45))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Countdown(context: context, size: 34)
                        Text(Copy.beside(context))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer(minLength: 0)
                        ActionButton(context: context, tone: tone)
                    }
                }
            } compactLeading: {
                // One dot — no icon, no app name.
                Circle()
                    .fill(context.state.phase == .paused ? Color.white.opacity(0.35) : tone)
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                Countdown(context: context, size: 15, weight: .regular)
                    .frame(minWidth: 44)
            } minimal: {
                Circle()
                    .fill(context.state.phase == .paused ? Color.white.opacity(0.35) : tone)
                    .frame(width: 8, height: 8)
            }
            .keylineTint(tone)
        }
    }
}

// MARK: - Lock Screen card

private struct LockScreenCard: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    private var tone: Color { Color(hex: context.attributes.accentHex) }
    private var state: FocusActivityAttributes.ContentState { context.state }
    private var isLastStretch: Bool { state.isLastStretch }
    private var isPaused: Bool { state.phase == .paused }
    private var isFinished: Bool { state.phase == .finished }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    eyebrow
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Countdown(context: context,
                                  size: 36,
                                  color: numeralColor)
                        Text(Copy.beside(context))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(isPaused ? 0.34 : 0.5))
                    }
                    .padding(.top, 11)
                }
                Spacer(minLength: 0)
                ActionButton(context: context, tone: tone)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 20)

            progressRule
        }
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(isLastStretch ? tone.opacity(0.16)
                              : .white.opacity(isPaused ? 0.055 : 0.07),
                              lineWidth: 1)
        )
    }

    private var eyebrow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(Copy.eyebrow(context))
                .font(.system(size: 11))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(isPaused ? 0.34 : 0.45))
            Spacer(minLength: 0)
            if let trailing = Copy.trailing(context) {
                Text(trailing)
                    .font(.system(size: 11))
                    .tracking(1.5)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private var panel: Color {
        if isLastStretch { return tone.opacity(0.07) }
        return .white.opacity(isPaused ? 0.035 : 0.055)
    }

    private var numeralColor: Color {
        if isPaused { return .white.opacity(0.5) }
        if isLastStretch { return tone.opacity(0.85).blended() }
        return Color(white: 0.93)
    }

    /// The 2pt rule across the bottom: a tone gradient while running, empty
    /// while held, and solid tone once the session is done.
    private var progressRule: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(.white.opacity(0.07))
                if isFinished {
                    Rectangle().fill(tone)
                } else if !isPaused {
                    Rectangle()
                        .fill(LinearGradient(colors: [tone.opacity(0.35), tone],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * fraction)
                }
            }
        }
        .frame(height: 2)
    }

    private var fraction: Double {
        let total = state.endDate.timeIntervalSince(state.startDate)
        guard total > 0 else { return 0 }
        let done = Date().timeIntervalSince(state.startDate)
        return min(1, max(0, done / total))
    }
}

// MARK: - Countdown

/// The one thin numeral. Live phases count themselves down from the range;
/// held and finished states show the value they were given, because a date
/// range can't stand still.
private struct Countdown: View {
    let context: ActivityViewContext<FocusActivityAttributes>
    var size: CGFloat
    var weight: Font.Weight = .ultraLight
    var color: Color = Color(white: 0.93)

    var body: some View {
        Group {
            if let frozen = context.state.frozenSeconds {
                Text(Self.clock(frozen))
            } else {
                Text(timerInterval: context.state.startDate...context.state.endDate,
                     countsDown: true)
            }
        }
        .font(.system(size: size, weight: weight))
        .monospacedDigit()
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Action button

/// Resume on a held session. Nothing otherwise — a running session has nothing
/// worth interrupting it for, and a finished one is over.
///
/// There used to be an "Again" here on the finished card. It is gone with the
/// card itself: a session now clears the Lock Screen when it ends, and where to
/// go next is the summary screen's job, not a notification's.
private struct ActionButton: View {
    let context: ActivityViewContext<FocusActivityAttributes>
    let tone: Color

    var body: some View {
        switch context.state.phase {
        case .paused:
            Button(intent: ResumeFocusIntent()) {
                Text("Resume")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "0A0B0E"))
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .background(Capsule().fill(tone))
            }
            .buttonStyle(.plain)
        default:
            EmptyView()
        }
    }
}

// MARK: - Copy

/// Every string on the card, in one place. The spec's voice: plain, present
/// tense, never congratulatory mid-session.
private enum Copy {
    static func eyebrow(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        let name = context.attributes.profileName.uppercased()
        switch context.state.phase {
        case .paused:
            return "\(name) · PAUSED"
        case .finished:
            let from = time(context.state.startDate)
            let to = time(context.state.endDate)
            return "\(name) · \(from) TO \(to)"
        case .breakTime:
            return "BREAK"
        case .upcoming:
            return "\(name) · SOON"
        case .focus:
            return name
        }
    }

    /// The small right-hand note — when this ends. Nothing once it has.
    static func trailing(_ context: ActivityViewContext<FocusActivityAttributes>) -> String? {
        switch context.state.phase {
        case .focus, .breakTime, .upcoming:
            return "until \(time(context.state.endDate))"
        case .paused, .finished:
            return nil
        }
    }

    static func beside(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        switch context.state.phase {
        case .paused:   return "held for you"
        case .finished: return "kept, start to end"
        case .breakTime: return "left of your break"
        case .upcoming: return "until it begins"
        case .focus:
            return context.state.isLastStretch ? "don\u{2019}t stop now" : "left of a quiet hour"
        }
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

private enum Island {
    static func trailing(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        Copy.trailing(context) ?? ""
    }
}

private extension Color {
    /// Lift a tone toward white for the last-stretch numeral (the spec's
    /// #B7C4F1 against a #7C93E8 tone).
    func blended() -> Color {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: Double(r + (1 - r) * 0.45),
                     green: Double(g + (1 - g) * 0.45),
                     blue: Double(b + (1 - b) * 0.45))
        #else
        return self
        #endif
    }
}
