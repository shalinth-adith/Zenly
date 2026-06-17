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
        List {
            Section("This week") {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName)
                                .font(.headline)
                            Text("\(member.streak)-day streak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(member.weeklyMinutes) min")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !accountability.isConnected {
                Section {
                    Label("Add accountability friends", systemImage: "person.2.fill")
                        .font(.subheadline)
                    Text("Connect with iCloud to compare focus time with friends. Coming soon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Accountability")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { members = accountability.leaderboard() }
    }
}
