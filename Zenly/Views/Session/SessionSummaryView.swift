//
//  SessionSummaryView.swift
//  Zenly
//
//  Celebration screen shown when a focus session finishes. Confetti + haptic
//  (fired by the controller) reward completion; offers a break or returns home.
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
            if let summary = session.summary {
                content(summary)
                if summary.wasCompleted {
                    ConfettiView()
                        .ignoresSafeArea()
                }
            }
        }
        .onAppear {
            if session.summary?.wasCompleted == true {
                newBadges = achievements.evaluate()
            }
        }
    }

    private func content(_ summary: SessionSummary) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: summary.wasCompleted ? "checkmark.seal.fill" : "flag.checkered")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: summary.accentHex))

            Text(summary.wasCompleted ? "Nice work!" : "Session ended")
                .font(.largeTitle.bold())

            Text(detail(summary))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if summary.streak > 0 {
                Label("\(summary.streak)-day streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.orange.opacity(0.12), in: Capsule())
            }

            if !newBadges.isEmpty {
                VStack(spacing: 6) {
                    ForEach(newBadges) { badge in
                        Label("New badge — \(badge.title)", systemImage: badge.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(hex: badge.accentHex))
                    }
                }
                .padding(.top, 4)
            }

            reviewSection

            Spacer()

            VStack(spacing: 12) {
                if session.canTakeBreak {
                    Button {
                        session.saveReview(rating: rating, note: note)
                        session.startBreak()
                    } label: {
                        Label("Take a break", systemImage: "cup.and.saucer.fill")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Done") {
                        session.saveReview(rating: rating, note: note)
                        session.dismissSummary()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button("Done") {
                        session.saveReview(rating: rating, note: note)
                        session.dismissSummary()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .padding()
    }

    private var reviewSection: some View {
        VStack(spacing: 10) {
            Text("How focused were you?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button { rating = i } label: {
                        Image(systemName: i <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(i == 1 ? "1 star" : "\(i) stars")
                    .accessibilityAddTraits(i == rating ? [.isButton, .isSelected] : .isButton)
                }
            }
            TextField("What did you work on? (optional)", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
        }
        .padding(.horizontal, 32)
    }

    private func detail(_ summary: SessionSummary) -> String {
        if summary.wasCompleted {
            return "You focused for \(summary.completedMinutes) minutes."
        } else {
            return "You focused for \(summary.completedMinutes) of \(summary.plannedMinutes) planned minutes."
        }
    }
}
