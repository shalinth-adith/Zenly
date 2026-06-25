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
        ZStack {
            ZenlyBackground()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(achievements.definitions) { badge in
                        let earned = achievements.isEarned(badge.id)
                        let accent = Color(hex: badge.accentHex)
                        VStack(spacing: 8) {
                            Image(systemName: badge.systemImage)
                                .font(.system(size: 30))
                                .foregroundStyle(earned ? .white : ZTheme.Palette.text(0.45))
                                .frame(width: 68, height: 68)
                                .background(
                                    Circle()
                                        .fill(earned ? accent : ZTheme.Palette.matteRaised)
                                        .overlay(Circle().strokeBorder(
                                            earned ? .clear : ZTheme.Palette.matteBorder, lineWidth: 1))
                                )
                                .shadow(color: earned ? accent.opacity(0.4) : .clear, radius: 12)
                            Text(badge.title)
                                .font(ZTheme.Font.display(13, weight: .semibold))
                                .foregroundStyle(ZTheme.Palette.textPrimary)
                                .multilineTextAlignment(.center)
                            Text(badge.detail)
                                .font(ZTheme.Font.body(11))
                                .foregroundStyle(ZTheme.Palette.text(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .opacity(earned ? 1 : 0.55)
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Badges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { achievements.evaluate() }
    }
}
