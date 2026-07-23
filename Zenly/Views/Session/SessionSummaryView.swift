//
//  SessionSummaryView.swift
//  Zenly
//
//  Celebration screen shown when a focus session finishes. Confetti + haptic
//  (fired by the controller) reward completion; offers a break or returns home.
//
//  Redesign: a frosted glass celebration card with the complete-state Focus Orb
//  on the session aurora (Claude Design spec, Zenly.dc.html). Logic unchanged.
//

import SwiftUI

struct SessionSummaryView: View {
    @Environment(FocusSessionController.self) private var session
    @Environment(AchievementService.self) private var achievements

    @State private var newBadges: [BadgeDefinition] = []
    @State private var rating = 0
    @State private var note = ""

    var body: some View {
        ZStack {
            ZenlyBackground(variant: .session)
            if let summary = session.summary {
                if summary.wasCompleted {
                    ConfettiView().ignoresSafeArea()
                }
                content(summary)
            }
        }
        .onAppear {
            if session.summary?.wasCompleted == true {
                newBadges = achievements.evaluate()
            }
        }
    }

    private func content(_ summary: SessionSummary) -> some View {
        ScrollView {
            VStack(spacing: ZTheme.Spacing.lg) {
                celebrationCard(summary)

                VStack(spacing: 12) {
                    if session.canTakeBreak {
                        Button {
                            session.saveReview(rating: rating, note: note)
                            session.startBreak()
                        } label: {
                            Label("Take a break", systemImage: "cup.and.saucer.fill")
                        }
                        .buttonStyle(.zenlyPrimary(tint: ZTheme.tone(forHex: summary.accentHex)))

                        Button("Done") {
                            session.saveReview(rating: rating, note: note)
                            session.dismissSummary()
                        }
                        .buttonStyle(.zenlySecondary)
                    } else {
                        Button("Done") {
                            session.saveReview(rating: rating, note: note)
                            session.dismissSummary()
                        }
                        .buttonStyle(.zenlyPrimary(tint: ZTheme.tone(forHex: summary.accentHex)))
                    }
                }
            }
            .padding(.horizontal, ZTheme.Spacing.xl)
            .padding(.vertical, 40)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func celebrationCard(_ summary: SessionSummary) -> some View {
        VStack(spacing: ZTheme.Spacing.md) {
            if summary.wasCompleted {
                FocusOrb.completeMark(diameter: 128)
            } else {
                FocusOrb(state: .idle, diameter: 128) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(ZTheme.Palette.text(0.7))
                }
            }

            VStack(spacing: 4) {
                Text(summary.wasCompleted ? "Nice work!" : "Session ended")
                    .font(ZTheme.Font.display(30, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(summary.wasCompleted ? "You stayed focused for" : "You focused for")
                    .font(ZTheme.Font.body(15))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.completedMinutes)")
                        .font(ZTheme.Font.numeral(42, weight: .bold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text(summary.wasCompleted ? "min" : "of \(summary.plannedMinutes) min")
                        .font(ZTheme.Font.numeral(20, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.6))
                }
            }

            if summary.streak > 0 {
                Label("\(summary.streak)-day streak", systemImage: "flame.fill")
                    .font(ZTheme.Font.display(14, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.streak)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ZTheme.Palette.streak.opacity(0.14), in: Capsule())
            }

            Divider().overlay(ZTheme.Palette.glassStroke)

            reviewSection

            ForEach(newBadges) { badge in
                badgeRow(badge)
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: ZTheme.Radius.sheet, padding: 26)
    }

    private func badgeRow(_ badge: BadgeDefinition) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [ZTheme.Palette.violet, ZTheme.Palette.brand],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: badge.systemImage)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("BADGE UNLOCKED")
                    .font(ZTheme.Font.body(11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(ZTheme.Palette.lavenderSoft)
                Text(badge.title)
                    .font(ZTheme.Font.display(16, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
            }
            Spacer()
        }
        .padding(13)
        .background(ZTheme.Palette.violet.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ZTheme.Radius.button, style: .continuous)
            .strokeBorder(ZTheme.Palette.violet.opacity(0.4), lineWidth: 1))
    }

    private var reviewSection: some View {
        VStack(spacing: ZTheme.Spacing.sm) {
            Text("How focused were you?")
                .font(ZTheme.Font.body(14, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.text(0.7))
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { i in
                    Button { Haptics.light(); rating = i } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(i <= rating ? ZTheme.Palette.streakWarm : ZTheme.Palette.text(0.35))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(i == 1 ? "1 star" : "\(i) stars")
                    .accessibilityAddTraits(i == rating ? [.isButton, .isSelected] : .isButton)
                }
            }
            TextField("What did you work on? (optional)", text: $note, axis: .vertical)
                .font(ZTheme.Font.body(14))
                .padding(10)
                .background(ZTheme.Palette.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(ZTheme.Palette.glassStroke, lineWidth: 1))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .tint(ZTheme.Palette.brand)
                .lineLimit(1...3)
        }
    }
}
