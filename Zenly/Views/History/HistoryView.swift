//
//  HistoryView.swift
//  Zenly
//
//  Chronological log of past focus sessions with duration, outcome, rating, and
//  the review note.
//

import SwiftUI

struct HistoryView: View {
    @State private var sessions: [FocusSession] = []

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your focus sessions will appear here.")
                )
            } else {
                List {
                    ForEach(sessions, id: \.objectID) { session in
                        row(session)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sessions = SessionHistory().recentFocusSessions() }
    }

    private func row(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(session.profileName ?? "Focus")
                    .font(.headline)
                Spacer()
                Text("\(session.completedMinutes) min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if let date = session.startedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if session.endedEarly {
                    Label("ended early", systemImage: "flag.checkered")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Label("completed", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            if session.rating > 0 {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= Int(session.rating) ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
            }

            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
