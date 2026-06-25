//
//  LeaderboardView.swift
//  Zenly
//
//  Accountability leaderboard ranked by this week's focus minutes. Local-first:
//  shows just you until CloudKit friend sync is enabled (Phase 4 follow-up).
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(AccountabilityService.self) private var accountability
    @State private var members: [LeaderboardMember] = []

    var body: some View {
        ZStack {
            ZenlyBackground()

            List {
                Text("This week")
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.85))
                    .plainRow()

                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(ZTheme.Font.numeral(18, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(ZTheme.Palette.text(0.5))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(ZTheme.Font.display(16, weight: .semibold))
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                            Text("\(member.streak)-day streak")
                                .font(ZTheme.Font.body(12))
                                .foregroundStyle(ZTheme.Palette.text(0.5))
                        }
                        Spacer()
                        Text("\(member.weeklyMinutes) min")
                            .font(ZTheme.Font.numeral(15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(ZTheme.Palette.brandBright)
                    }
                    .glassCard(padding: ZTheme.Spacing.md)
                    .plainRow()
                }

                if !accountability.isConnected {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Add accountability friends", systemImage: "person.2.fill")
                            .font(ZTheme.Font.display(15, weight: .semibold))
                            .foregroundStyle(ZTheme.Palette.textPrimary)
                        Text("Connect with iCloud to compare focus time with friends. Coming soon.")
                            .font(ZTheme.Font.body(13))
                            .foregroundStyle(ZTheme.Palette.text(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .plainRow()
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Accountability")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { members = accountability.leaderboard() }
    }
}
