//
//  BadgesView.swift
//  Zenly
//
//  Grid of all earnable badges; earned ones are highlighted in their accent.
//

import SwiftUI

struct BadgesView: View {
    @Environment(AchievementService.self) private var achievements

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(achievements.definitions) { badge in
                    let earned = achievements.isEarned(badge.id)
                    VStack(spacing: 8) {
                        Image(systemName: badge.systemImage)
                            .font(.system(size: 30))
                            .foregroundStyle(earned ? .white : .secondary)
                            .frame(width: 68, height: 68)
                            .background(
                                earned ? Color(hex: badge.accentHex) : Color(.secondarySystemFill),
                                in: Circle()
                            )
                        Text(badge.title)
                            .font(.caption.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(badge.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(earned ? 1 : 0.5)
                }
            }
            .padding()
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { achievements.evaluate() }
    }
}
