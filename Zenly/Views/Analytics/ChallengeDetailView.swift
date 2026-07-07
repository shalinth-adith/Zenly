//
//  ChallengeDetailView.swift
//  Zenly
//
//  Full-screen detail for the daily challenge: today's goal with a progress bar
//  and an explainer, plus a history of previously completed challenges. Presented
//  as a sheet from the Insights challenge card.
//

import SwiftUI

struct ChallengeDetailView: View {
    @Environment(ChallengeService.self) private var challenges
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ZenlyBackground()

                ScrollView {
                    VStack(spacing: ZTheme.Spacing.lg) {
                        todayCard
                        historySection
                    }
                    .padding(.horizontal, ZTheme.Spacing.lg)
                    .padding(.vertical, ZTheme.Spacing.md)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Daily Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Today

    private var todayCard: some View {
        let c = challenges.challenge
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                icon(c.systemImage, filled: challenges.isComplete)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TODAY")
                        .font(ZTheme.Font.body(11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(ZTheme.Palette.text(0.5))
                    Text(c.title)
                        .font(ZTheme.Font.display(18, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                }
                Spacer()
            }

            // Progress
            VStack(spacing: 8) {
                ProgressTrack(fraction: challenges.fraction, complete: challenges.isComplete)
                HStack {
                    if challenges.isComplete {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(ZTheme.Font.body(13, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.teal)
                    } else {
                        Text("\(challenges.progress) of \(challenges.challenge.target)\(unitSuffix)")
                            .font(ZTheme.Font.body(13, weight: .medium))
                            .foregroundStyle(ZTheme.Palette.text(0.6))
                    }
                    Spacer()
                    Text("\(Int(challenges.fraction * 100))%")
                        .font(ZTheme.Font.numeral(14, weight: .bold))
                        .foregroundStyle(ZTheme.Palette.lavenderSoft)
                }
            }

            Text(explainer(for: c))
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var unitSuffix: String {
        switch challenges.challenge.kind {
        case .minutes:     return " min"
        case .sessions:    return " sessions"
        case .longSession: return ""
        }
    }

    private func explainer(for c: DailyChallenge) -> String {
        switch c.kind {
        case .minutes:
            return "Focus for a total of \(c.target) minutes today, across any number of sessions."
        case .sessions:
            return "Complete \(c.target) focus sessions today. Sessions you end early don't count."
        case .longSession:
            return "Complete a single focus session of \(c.target) minutes or more in one sitting."
        }
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        if challenges.completedHistory.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "rosette")
                    .font(.system(size: 30))
                    .foregroundStyle(ZTheme.Palette.streakWarm)
                Text("No completed challenges yet")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("Finish today's goal and it'll show up here.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .glassCard(padding: 22)
        } else {
            VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
                Text("Completed")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(challenges.completedHistory) { item in
                    HStack(spacing: 12) {
                        icon(item.systemImage, filled: true, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(ZTheme.Font.body(14, weight: .medium))
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                                .lineLimit(1)
                            Text(item.completedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(ZTheme.Font.body(12))
                                .foregroundStyle(ZTheme.Palette.text(0.5))
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ZTheme.Palette.teal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(padding: 14)
                }
            }
        }
    }

    // MARK: Bits

    private func icon(_ name: String, filled: Bool, size: CGFloat = 44) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(ZTheme.Palette.violet.opacity(filled ? 0.28 : 0.18))
                .overlay(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .strokeBorder(ZTheme.Palette.violet.opacity(0.4), lineWidth: 1))
                .frame(width: size, height: size)
            Image(systemName: name)
                .font(.system(size: size * 0.42))
                .foregroundStyle(ZTheme.Palette.lavenderSoft)
        }
    }
}

/// A simple rounded progress track used inside the challenge detail card.
private struct ProgressTrack: View {
    let fraction: Double
    let complete: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ZTheme.Palette.glassFill)
                Capsule()
                    .fill(complete ? ZTheme.Palette.teal : ZTheme.Palette.brandGlow)
                    .frame(width: max(6, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 10)
    }
}
