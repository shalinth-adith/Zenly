//
//  SessionDetailView.swift
//  Zenly
//
//  Drill-down for a single past focus session, pushed from HistoryView. Shows
//  the time spent and the distraction attempts (each time a blocked app was
//  reached for) that fell inside the session's window — attributed live from
//  the timestamped DistractionLog, plus the saved rating/note.
//

import SwiftUI

struct SessionDetailView: View {
    @Environment(ProfileStore.self) private var profiles

    let session: FocusSession

    // Distraction timestamps inside this session's window, resolved on appear.
    @State private var distractions: [Date] = []

    private var profile: FocusProfile? {
        let name = session.profileName ?? "Focus"
        return profiles.profiles.first { $0.name == name }
    }

    private var accent: Color {
        Color(hex: profile?.accentHex ?? "1A3FA8")
    }

    var body: some View {
        ZStack {
            ZenlyBackground()
            ScrollView {
                VStack(spacing: ZTheme.Spacing.lg) {
                    header
                    timeCard
                    distractionCard
                    if Int(session.rating) > 0 || (session.note?.isEmpty == false) {
                        reviewCard
                    }
                }
                .padding(.horizontal, ZTheme.Spacing.lg)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            if let start = session.startedAt, let end = session.endedAt {
                distractions = DistractionLog.attempts(from: start, to: end)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: ZTheme.Spacing.sm) {
            IconTile(systemImage: profile?.iconName ?? "timer", color: accent, size: 60, corner: 18)

            Text(session.profileName ?? "Focus")
                .font(ZTheme.Font.display(22, weight: .bold))
                .foregroundStyle(ZTheme.Palette.textPrimary)

            Text(dateLine)
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.55))

            outcomeChip
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var outcomeChip: some View {
        let completed = session.wasCompleted
        let tint = completed ? ZTheme.Palette.teal : ZTheme.Palette.streak
        return Label(completed ? "Completed" : "Ended early",
                     systemImage: completed ? "checkmark.circle.fill" : "flag.checkered")
            .font(ZTheme.Font.display(13, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tint.opacity(0.14), in: Capsule())
    }

    // MARK: - Time

    private var timeCard: some View {
        VStack(spacing: ZTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(session.completedMinutes))")
                    .font(ZTheme.Font.numeral(46, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(session.wasCompleted ? "min focused"
                                          : "of \(Int(session.plannedMinutes)) min")
                    .font(ZTheme.Font.numeral(18, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
            }

            Divider().overlay(ZTheme.Palette.matteBorder)

            HStack {
                timeColumn("Started", value: clock(session.startedAt))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.text(0.35))
                Spacer()
                timeColumn("Ended", value: clock(session.endedAt))
            }
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: ZTheme.Radius.card, padding: ZTheme.Spacing.lg)
    }

    private func timeColumn(_ label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(ZTheme.Font.body(11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(ZTheme.Palette.text(0.45))
            Text(value)
                .font(ZTheme.Font.display(17, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
        }
    }

    // MARK: - Distractions

    private var distractionCard: some View {
        VStack(alignment: .leading, spacing: ZTheme.Spacing.md) {
            HStack(spacing: 11) {
                IconTile(systemImage: "hand.tap.fill",
                         color: distractions.isEmpty ? ZTheme.Palette.teal : ZTheme.Palette.streak,
                         size: 42, corner: 13)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(distractions.count)")
                        .font(ZTheme.Font.numeral(24, weight: .bold))
                        .foregroundStyle(ZTheme.Palette.textPrimary)
                    Text(distractions.count == 1 ? "distraction" : "distractions")
                        .font(ZTheme.Font.body(12.5))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                }
                Spacer()
            }

            if distractions.isEmpty {
                Text("You stayed in the zone — no blocked apps reached for during this session.")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Each time you reached for a blocked app:")
                    .font(ZTheme.Font.body(12.5))
                    .foregroundStyle(ZTheme.Palette.text(0.55))

                VStack(spacing: 8) {
                    ForEach(Array(distractions.enumerated()), id: \.offset) { index, date in
                        distractionRow(index: index, date: date)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: ZTheme.Radius.card, padding: ZTheme.Spacing.lg)
    }

    private func distractionRow(index: Int, date: Date) -> some View {
        HStack(spacing: 11) {
            Text("\(index + 1)")
                .font(ZTheme.Font.numeral(13, weight: .bold))
                .foregroundStyle(ZTheme.Palette.streak)
                .frame(width: 24, height: 24)
                .background(ZTheme.Palette.streak.opacity(0.14), in: Circle())

            Text(clock(date))
                .font(ZTheme.Font.display(14, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)

            Spacer()

            Text(elapsedLabel(for: date))
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.45))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ZTheme.Palette.matte, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(ZTheme.Palette.matteBorder, lineWidth: 1))
    }

    // MARK: - Review

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
            if Int(session.rating) > 0 {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= Int(session.rating) ? "star.fill" : "star")
                            .font(.system(size: 15))
                            .foregroundStyle(i <= Int(session.rating)
                                             ? ZTheme.Palette.streakWarm : ZTheme.Palette.text(0.3))
                    }
                }
            }
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: ZTheme.Radius.card, padding: ZTheme.Spacing.lg)
    }

    // MARK: - Formatting

    private var dateLine: String {
        guard let start = session.startedAt else { return "" }
        return start.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func clock(_ date: Date?) -> String {
        (date ?? Date()).formatted(date: .omitted, time: .shortened)
    }

    /// Minutes into the session a distraction happened, e.g. "12 min in".
    private func elapsedLabel(for date: Date) -> String {
        guard let start = session.startedAt else { return "" }
        let minutes = max(0, Int(date.timeIntervalSince(start) / 60))
        return minutes == 0 ? "at start" : "\(minutes) min in"
    }
}
