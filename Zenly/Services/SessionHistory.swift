//
//  SessionHistory.swift
//  Zenly
//
//  Records completed/abandoned focus sessions to Core Data and derives streak +
//  today's focus minutes for the Home screen.
//

import CoreData
import Foundation

@MainActor
final class SessionHistory {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    @discardableResult
    func record(profileName: String,
                plannedMinutes: Int,
                completedMinutes: Int,
                kind: String,
                wasCompleted: Bool,
                endedEarly: Bool,
                startedAt: Date,
                endedAt: Date) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.profileName = profileName
        session.plannedMinutes = Int16(plannedMinutes)
        session.completedMinutes = Int16(completedMinutes)
        session.kind = kind
        session.wasCompleted = wasCompleted
        session.endedEarly = endedEarly
        session.startedAt = startedAt
        session.endedAt = endedAt
        try? context.save()
        return session
    }

    func save() {
        try? context.save()
    }

    /// Recent focus sessions (completed + ended-early), newest first.
    func recentFocusSessions(limit: Int = 100) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@", "focus")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }

    func completedFocusSessions() -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@ AND wasCompleted == YES", "focus")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func todayFocusMinutes() -> Int {
        let calendar = Calendar.current
        return completedFocusSessions()
            .filter { $0.startedAt.map { calendar.isDateInToday($0) } ?? false }
            .reduce(0) { $0 + Int($1.completedMinutes) }
    }

    /// Consecutive days (ending today or yesterday) with at least one completed
    /// focus session.
    func currentStreak() -> Int {
        let calendar = Calendar.current
        let days = Set(completedFocusSessions().compactMap { session in
            session.startedAt.map { calendar.startOfDay(for: $0) }
        })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
