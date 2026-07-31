//
//  QuietForm.swift
//  Zenly
//
//  The editor building blocks from the Quiet spec (Zenly Quiet.dc.html, screens
//  09–13 "New profile" and 16–19 "New schedule").
//
//  Why these exist: a SwiftUI `Form` cannot produce the comp's editors. The
//  design is a flat sheet with a 28pt gutter, 11pt uppercase tracked labels, a
//  22pt underlined value, a 12pt helper line under every field, and a pinned
//  footer holding a status line above a full-width tone CTA — none of which a
//  grouped inset list gives you. So the editors are hand-built from these
//  pieces, exactly like the Focus and Schedule screens already are.
//
//  The other half of the spec is *when* things turn red: nothing is flagged
//  while you type. Errors only appear after you press the CTA with something
//  missing (`npTried` / `scTried` in the design's logic). `QuietValidation`
//  below carries that "has the user tried yet" flag so both editors behave the
//  same way.
//

import SwiftUI

// MARK: - Metrics

/// The comp's editor measurements, in points (the comp is drawn at 402pt, the
/// iPhone 16 Pro width, so its px map 1:1).
enum QuietMetrics {
    static let gutter: CGFloat = 28
    /// Space above a section label that follows another section.
    static let sectionGap: CGFloat = 30
    static let labelSize: CGFloat = 11
    /// `letter-spacing: .16em` at 11pt.
    static let labelTracking: CGFloat = 1.76
    static let valueSize: CGFloat = 22
    static let helperSize: CGFloat = 12
    static let ctaHeight: CGFloat = 56
    static let chipRadius: CGFloat = 13
    static let tileRadius: CGFloat = 14
}

// MARK: - Deferred validation

/// Tracks whether the user has attempted to save yet. Fields stay neutral until
/// they have — the comp never flags a field the user hasn't finished with.
@Observable
final class QuietValidation {
    private(set) var hasTriedToSave = false

    /// Call from the CTA when the form is not yet valid.
    func flagMissingFields() { hasTriedToSave = true }

    /// True only once the user has tried to save AND the field is still bad.
    func flags(_ isBad: Bool) -> Bool { hasTriedToSave && isBad }

    /// The label / hairline color for a field: alert once flagged, else neutral.
    func labelColor(_ isBad: Bool) -> Color {
        flags(isBad) ? ZTheme.Palette.alert : ZTheme.Palette.text(0.30)
    }

    /// The soft wash behind an unfilled required control (icon grid, day row).
    func emptyFill(_ isBad: Bool) -> Color {
        flags(isBad) ? ZTheme.Palette.alertSoft : ZTheme.Palette.glassFill
    }
}

// MARK: - Scaffold

/// The editor shell: a "Cancel" + title header, a scrolling body, and a pinned
/// footer carrying the status line and the single tone CTA.
struct QuietEditorScaffold<Body: View>: View {
    let title: String
    let cancelTitle: String
    /// The footer's status line — grey guidance, or alert once save was blocked.
    let status: String
    let statusIsAlert: Bool
    let ctaTitle: String
    /// Stable identifier for the CTA, so UI tests can find each editor's save
    /// button by name rather than by position.
    var ctaIdentifier: String = "quiet-cta"
    /// The CTA only takes the tone when the form is ready; otherwise it sits as
    /// a flat neutral raise with dim ink (spec: `npCtaBg`/`npCtaFg`).
    let isReady: Bool
    let tone: Color
    let onCancel: () -> Void
    let onSubmit: () -> Void
    @ViewBuilder var content: () -> Body

    var body: some View {
        ZStack {
            ZenlyBackground()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, QuietMetrics.gutter)
                    .padding(.top, 26)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(cancelTitle) { Haptics.light(); onCancel() }
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .buttonStyle(.plain)
                .accessibilityIdentifier("quiet-cancel")
            Text(title)
                .font(ZTheme.Font.display(24, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 18)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuietStatusLine(text: status, isAlert: statusIsAlert)
            Button(ctaTitle) { onSubmit() }
                .buttonStyle(QuietCTAStyle(tone: tone, isReady: isReady))
                .accessibilityIdentifier(ctaIdentifier)
        }
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(ZTheme.Palette.night)
        // A short fade sitting just above the footer, so content scrolling
        // underneath dissolves into it instead of being sliced off. Drawn as an
        // overlay rather than part of the background, which would otherwise
        // resize and stop covering the footer itself.
        .overlay(alignment: .top) {
            LinearGradient(colors: [ZTheme.Palette.night.opacity(0), ZTheme.Palette.night],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
                .offset(y: -20)
                .allowsHitTesting(false)
        }
    }
}

/// The footer CTA. Ready = flat tone fill with dark ink (the single bright
/// element). Not ready = neutral raise with dim ink — visible, pressable, and
/// obviously not the thing to press yet.
struct QuietCTAStyle: ButtonStyle {
    var tone: Color
    var isReady: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZTheme.Font.display(16, weight: .semibold))
            .foregroundStyle(isReady ? Color(hex: "0A0B0E") : ZTheme.Palette.text(0.30))
            .frame(maxWidth: .infinity)
            .frame(height: QuietMetrics.ctaHeight)
            .background(
                RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
                    .fill(isReady ? tone : ZTheme.Palette.glassFill)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(ZTheme.Motion.bouncy, value: configuration.isPressed)
            .animation(ZTheme.Motion.smooth, value: isReady)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.light() }
            }
    }
}

// MARK: - Field pieces

/// 11pt uppercase tracked section label. Turns alert when its field is flagged.
struct QuietFieldLabel: View {
    let text: String
    var color: Color = ZTheme.Palette.text(0.30)
    /// Leading space when this label follows another section.
    var topPadding: CGFloat = 0

    var body: some View {
        Text(text.uppercased())
            .font(ZTheme.Font.body(QuietMetrics.labelSize))
            .tracking(QuietMetrics.labelTracking)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topPadding)
            .animation(ZTheme.Motion.smooth, value: color)
    }
}

/// The 12pt line under a field. Always present — it explains in the neutral
/// case and corrects in the flagged one, so the layout never jumps.
struct QuietHelper: View {
    let text: String
    var color: Color = ZTheme.Palette.text(0.30)

    var body: some View {
        Text(text)
            .font(ZTheme.Font.body(QuietMetrics.helperSize))
            .foregroundStyle(color)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 9)
    }
}

/// A helper line with a one-tap repair on the right ("Open that one",
/// "Use chatgpt.com", "Weekdays", "End at 2:50 PM"). The fix carries the tone —
/// it is the one thing to do next.
struct QuietHelperRow: View {
    let text: String
    var color: Color = ZTheme.Palette.text(0.30)
    let actionTitle: String
    var tone: Color = ZTheme.Palette.tone
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(text)
                .font(ZTheme.Font.body(QuietMetrics.helperSize))
                .foregroundStyle(color)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(actionTitle) { Haptics.light(); action() }
                .font(ZTheme.Font.body(QuietMetrics.helperSize, weight: .semibold))
                .foregroundStyle(tone)
                .buttonStyle(.plain)
                .fixedSize()
        }
        .padding(.top, 9)
    }
}

/// 1px rule under a field. Turns alert when the field is flagged.
struct QuietHairline: View {
    var color: Color = ZTheme.Palette.glassStroke

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1)
            .animation(ZTheme.Motion.smooth, value: color)
    }
}

/// The footer's status line: a small alert dot appears only once a save was
/// blocked, so the neutral state stays a plain grey sentence.
struct QuietStatusLine: View {
    let text: String
    var isAlert: Bool

    var body: some View {
        HStack(spacing: 9) {
            if isAlert {
                Circle()
                    .fill(ZTheme.Palette.alert)
                    .frame(width: 5, height: 5)
            }
            Text(text)
                .font(ZTheme.Font.body(QuietMetrics.helperSize))
                .foregroundStyle(isAlert ? ZTheme.Palette.alert : ZTheme.Palette.text(0.30))
                // The colour may animate; the words must not. Cross-fading one
                // sentence into another leaves both legible at once, which
                // reads as a rendering fault.
                .contentTransition(.identity)
                .animation(nil, value: text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .animation(ZTheme.Motion.smooth, value: isAlert)
        .accessibilityIdentifier("quiet-status")
    }
}

/// The 22pt underlined value field (profile name, schedule title).
struct QuietTextField: View {
    let placeholder: String
    @Binding var text: String
    var lineColor: Color = ZTheme.Palette.glassStroke

    var body: some View {
        VStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(ZTheme.Font.display(QuietMetrics.valueSize, weight: .regular))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .tint(ZTheme.Palette.tone)
                .padding(.top, 9)
                .padding(.bottom, 11)
            QuietHairline(color: lineColor)
        }
    }
}

/// A pill for a discrete choice — weekday letters, profile names, domains.
struct QuietChip: View {
    let title: String
    var isSelected: Bool
    var tone: Color = ZTheme.Palette.tone
    /// Background when unselected — normally the neutral raise, or the alert
    /// wash when the whole group is flagged as unanswered.
    var restingFill: Color = ZTheme.Palette.glassFill
    var height: CGFloat? = nil
    var expands: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Text(title)
                .font(ZTheme.Font.body(isSelected ? 14 : 14))
                .foregroundStyle(isSelected ? Color(hex: "0A0B0E") : ZTheme.Palette.text(0.55))
                .padding(.horizontal, height == nil ? 16 : 0)
                .padding(.vertical, height == nil ? 11 : 0)
                .frame(maxWidth: expands ? .infinity : nil)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: QuietMetrics.chipRadius, style: .continuous)
                        .fill(isSelected ? tone : restingFill)
                )
        }
        .buttonStyle(.plain)
        .animation(ZTheme.Motion.smooth, value: isSelected)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Label + optional sub-label on the left, a tone-tinted switch on the right.
struct QuietToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tone: Color = ZTheme.Palette.tone

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(ZTheme.Font.body(12))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                }
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tone)
        }
        .padding(.vertical, 15)
    }
}

/// Label on the left, a dim value and a chevron on the right — the row that
/// pushes to a picker.
struct QuietDisclosureRow: View {
    let title: String
    let value: String
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            HStack(spacing: 14) {
                Text(title)
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Spacer(minLength: 0)
                Text(value)
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.30))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
    }
}

/// A big tabular value with − / + squares — the comp's session-length control.
struct QuietStepperRow: View {
    let value: String
    var canDecrement: Bool
    var canIncrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(value)
                .font(ZTheme.Font.numeral(QuietMetrics.valueSize))
                .foregroundStyle(ZTheme.Palette.textPrimary)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                stepButton("minus", enabled: canDecrement, action: onDecrement)
                stepButton("plus", enabled: canIncrement, action: onIncrement)
            }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(enabled ? ZTheme.Palette.text(0.55) : ZTheme.Palette.text(0.30))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ZTheme.Palette.glassFill)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "minus" ? "Decrease" : "Increase")
    }
}

// MARK: - Wrapping row

/// Lays chips out left to right and wraps to a new line when the width runs
/// out — `LazyVGrid` can't do this because the chips are each a different
/// width (a domain, a profile name).
struct QuietFlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = layout(subviews: subviews, width: width)
        let height = rows.reduce(CGFloat.zero) { $0 + $1.height } +
            lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let rows = layout(subviews: subviews, width: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && projected > width {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = projected
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Hold to end

/// The comp's "Hold to end early" (screen 02): a quiet label with a hairline
/// under it that fills with the tone while you hold, and fires at three seconds.
///
/// Why a hold and not a tap: ending a session is the one destructive thing on
/// this screen, and it sits under your thumb for the whole session. A hold
/// cannot be done by accident, and — unlike a confirmation dialog — it doesn't
/// interrupt the screen to ask a question.
struct QuietHoldToEnd: View {
    var tone: Color = ZTheme.Palette.tone
    var idleLabel: String = "Hold to end early"
    var holdingLabel: String = "Keep holding…"
    /// Seconds of continuous hold required.
    var duration: TimeInterval = 3
    let action: () -> Void

    @State private var progress: Double = 0
    @State private var timer: Timer?

    private var label: String { progress > 0 ? holdingLabel : idleLabel }

    var body: some View {
        Text(label)
            .font(ZTheme.Font.body(14))
            .foregroundStyle(ZTheme.Palette.text(0.30))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(ZTheme.Palette.glassStroke)
                        Rectangle()
                            .fill(tone)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in start() }
                    .onEnded { _ in cancel() }
            )
            .onDisappear(perform: cancel)
            .accessibilityLabel(idleLabel)
            .accessibilityHint("Press and hold for \(Int(duration)) seconds")
            .accessibilityAddTraits(.isButton)
            // VoiceOver cannot express a hold, so a direct activation ends it.
            .accessibilityAction { action() }
            .accessibilityIdentifier("session-hold-to-end")
    }

    private func start() {
        guard timer == nil else { return }
        Haptics.light()
        let step = 0.05
        timer = Timer.scheduledTimer(withTimeInterval: step, repeats: true) { t in
            progress += step / duration
            if progress >= 1 {
                t.invalidate()
                timer = nil
                progress = 0
                Haptics.success()
                action()
            }
        }
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
    }
}

/// A 64pt hairline circle holding one glyph — the comp's pause control.
struct QuietCircleButton: View {
    let systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: { Haptics.light(); action() }) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .frame(width: 64, height: 64)
                .background(
                    Circle().strokeBorder(ZTheme.Palette.glassStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Blocking sheet (shared by both editors)

/// The "Couldn't save" sheet from comp 12 — a bottom card over a dimmed form.
/// Reused for schedules, which hit the same Screen Time gate.
struct QuietBlockedSaveSheet: View {
    let eyebrow: String
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String
    var tone: Color = ZTheme.Palette.tone
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow.uppercased())
                .font(ZTheme.Font.body(11))
                .tracking(3.08)                       // .28em at 11pt
                .foregroundStyle(ZTheme.Palette.alert)
            Text(title)
                .font(ZTheme.Font.display(22, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            Text(message)
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            VStack(spacing: 4) {
                Button(primaryTitle) { onPrimary() }
                    .buttonStyle(QuietCTAStyle(tone: tone, isReady: true))
                Button(secondaryTitle) { Haptics.light(); onSecondary() }
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.plain)
            }
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, QuietMetrics.gutter)
        .padding(.top, 34)
        .padding(.bottom, 16)
        .background(ZTheme.Palette.night)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(ZTheme.Palette.night)
    }
}
