//
//  TasksView.swift
//  Zenly
//
//  Built-in focus task list with optional Reminders import/export.
//

import SwiftUI

struct TasksView: View {
    @Environment(TaskService.self) private var tasks
    @Environment(\.dismiss) private var dismiss
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add a task", text: $newTitle)
                            .onSubmit(addTask)
                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section {
                    ForEach(tasks.tasks, id: \.objectID) { task in
                        HStack(spacing: 12) {
                            Button {
                                tasks.toggle(task)
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(task.title ?? "")
                                .strikethrough(task.isDone)
                                .foregroundStyle(task.isDone ? .secondary : .primary)

                            Spacer()

                            if tasks.remindersAuthorized {
                                Button {
                                    tasks.exportToReminders(task)
                                } label: {
                                    Image(systemName: "arrow.up.forward.app")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tint)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { tasks.delete(task) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await importReminders() }
                        } label: {
                            Label("Import from Reminders", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func addTask() {
        tasks.add(newTitle)
        newTitle = ""
    }

    private func importReminders() async {
        if !tasks.remindersAuthorized { await tasks.requestRemindersAccess() }
        await tasks.importFromReminders()
    }
}
