//
//  TaskService.swift
//  Zenly
//
//  Built-in focus task list (Core Data) with optional two-way bridging to the
//  Reminders app via EventKit.
//

import Foundation
import CoreData
import EventKit
import Observation

@Observable
@MainActor
final class TaskService {
    private(set) var tasks: [FocusTask] = []
    private(set) var remindersAuthorized = false

    private let context: NSManagedObjectContext
    private let store = EKEventStore()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        remindersAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        fetch()
    }

    var remindersDenied: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .denied
    }

    func fetch() {
        let request = FocusTask.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \FocusTask.isDone, ascending: true),
            NSSortDescriptor(keyPath: \FocusTask.sortIndex, ascending: true)
        ]
        tasks = (try? context.fetch(request)) ?? []
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let task = FocusTask(context: context)
        task.id = UUID()
        task.title = trimmed
        task.isDone = false
        task.createdAt = Date()
        task.sortIndex = Int16(tasks.count)
        save()
        fetch()
    }

    func toggle(_ task: FocusTask) {
        task.isDone.toggle()
        save()
        fetch()
    }

    func delete(_ task: FocusTask) {
        context.delete(task)
        save()
        fetch()
    }

    // MARK: - Reminders bridge

    func requestRemindersAccess() async {
        do {
            remindersAuthorized = try await store.requestFullAccessToReminders()
        } catch {
            print("[Zenly] Reminders access failed: \(error)")
            remindersAuthorized = false
        }
    }

    /// Pull incomplete reminders from the default list into the task list.
    func importFromReminders() async {
        guard remindersAuthorized else { return }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
        let existing = Set(tasks.compactMap { $0.title })
        for reminder in reminders where !existing.contains(reminder.title) {
            add(reminder.title)
        }
    }

    /// Push a task to the Reminders app.
    func exportToReminders(_ task: FocusTask) {
        guard remindersAuthorized, let title = task.title else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        try? store.save(reminder, commit: true)
    }

    private func save() {
        guard context.hasChanges else { return }
        do { try context.save() }
        catch { print("[Zenly] TaskService save failed: \(error)") }
    }
}
