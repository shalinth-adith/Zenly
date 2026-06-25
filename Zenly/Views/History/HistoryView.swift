//
//  HistoryView.swift
//  Zenly
//
//  Chronological log of past focus sessions with duration, outcome, rating, and
//  the review note.
//
//  Redesign: a summary strip, profile filter pills, and day-grouped glass
//  session cards with rating dots, on the aurora (Claude Design spec,
//  Zenly.dc.html · screen 09). Data and grouping are derived from real sessions.
//

import SwiftUI

struct HistoryView: View {
    @Environment(ProfileStore.self) private var profiles

    @State private var sessions: [FocusSession] = []
    @State private var streak = 0
    @State private var filter: String? = nil      // nil = All; else profile name

    var body: some View {
        ZStack {
            ZenlyBackground()

            if sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your focus sessions will appear here.")
                )
            } else {
                ScrollView {
                    VStack(spacing: ZTheme.Spacing.lg) {
                        summaryStrip
                        if profileNames.count > 1 { filterPills }
                        ForEach(groupedDays, id: \.key) { group in
                            dayGroup(group)
                        }
                    }
                    .padding(.horizontal, ZTheme.Spacing.lg)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            let history = SessionHistory()
            sessions = history.recentFocusSessions()
            streak = history.currentStreak()
        }
    }

    // MARK: - Summary

    private var totalMinutes: Int { filtered.reduce(0) { $0 + Int($1.completedMinutes) } }

    private var summaryStrip: some View {
        HStack(spacing: ZTheme.Spacing.sm) {
            miniStat(value: "\(filtered.count)", label: "sessions", color: ZTheme.Palette.textPrimary)
            miniStat(value: hoursLabel(totalMinutes), label: "focused", color: ZTheme.Palette.textPrimary)
            miniStat(value: "\(streak)", label: "day streak", color: ZTheme.Palette.teal)
        }
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(ZTheme.Font.numeral(26, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(ZTheme.Font.body(12))
                .foregroundStyle(ZTheme.Palette.text(0.55))
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 18, padding: ZTheme.Spacing.md)
    }

    // MARK: - Filter pills

    private var profileNames: [String] {
        var seen = Set<String>(), ordered: [String] = []
        for s in sessions {
            let n = s.profileName ?? "Focus"
            if seen.insert(n).inserted { ordered.append(n) }
        }
        return ordered
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "All", value: nil)
                ForEach(profileNames, id: \.self) { name in
                    pill(title: name, value: name)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(title: String, value: String?) -> some View {
        let isOn = filter == value
        return Button {
            Haptics.light()
            filter = value
        } label: {
            Text(title)
                .font(ZTheme.Font.display(13, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ZTheme.Palette.matte)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isOn ? ZTheme.Palette.brand : ZTheme.Palette.matteBorder,
                                      lineWidth: isOn ? 1.5 : 1)
                )
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ZTheme.Palette.brand.opacity(isOn ? 0.16 : 0)))
                .shadow(color: isOn ? ZTheme.Palette.brand.opacity(0.4) : .clear, radius: 12)
        }
        .buttonStyle(.plain)
        .animation(ZTheme.Motion.smooth, value: isOn)
    }

    // MARK: - Day groups

    private var filtered: [FocusSession] {
        guard let filter else { return sessions }
        return sessions.filter { ($0.profileName ?? "Focus") == filter }
    }

    private var groupedDays: [(key: Date, value: [FocusSession])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { session in
            cal.startOfDay(for: session.startedAt ?? .distantPast)
        }
        return groups.sorted { $0.key > $1.key }
    }

    private func dayGroup(_ group: (key: Date, value: [FocusSession])) -> some View {
        let dayMinutes = group.value.reduce(0) { $0 + Int($1.completedMinutes) }
        return VStack(alignment: .leading, spacing: ZTheme.Spacing.sm) {
            HStack {
                Text(dayLabel(group.key))
                    .font(ZTheme.Font.display(14, weight: .bold))
                    .foregroundStyle(ZTheme.Palette.text(0.85))
                Spacer()
                Text("\(dayMinutes) min")
                    .font(ZTheme.Font.body(12))
                    .foregroundStyle(ZTheme.Palette.text(0.45))
            }
            .padding(.horizontal, 2)

            ForEach(group.value, id: \.objectID) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        let name = session.profileName ?? "Focus"
        let profile = profiles.profiles.first { $0.name == name }
        let accent = Color(hex: profile?.accentHex ?? "1A3FA8")
        return HStack(spacing: 13) {
            IconTile(systemImage: profile?.iconName ?? "timer", color: accent, size: 42, corner: 13)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(ZTheme.Font.display(15, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(subtitle(session))
                    .font(ZTheme.Font.body(12.5))
                    .foregroundStyle(ZTheme.Palette.text(0.5))
            }
            Spacer()
            ratingDots(Int(session.rating))
        }
        .glassCard(radius: 18, padding: 13)
    }

    private func ratingDots(_ rating: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < rating ? ZTheme.Palette.brandBright : Color.white.opacity(0.18))
                    .frame(width: 7, height: 7)
                    .shadow(color: i < rating ? ZTheme.Palette.brandBright : .clear, radius: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(rating > 0 ? "\(rating) of 5" : "unrated")
    }

    // MARK: - Formatting

    private func subtitle(_ session: FocusSession) -> String {
        let time = (session.startedAt ?? Date()).formatted(date: .omitted, time: .shortened)
        var s = "\(time) · \(session.completedMinutes) min"
        if session.endedEarly { s += " · ended early" }
        return s
    }

    private func hoursLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
