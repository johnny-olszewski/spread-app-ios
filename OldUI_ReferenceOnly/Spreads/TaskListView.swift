//
//  TaskListView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A text-based task list that groups tasks by their target date within the spread.
/// - Year spread: groups by month
/// - Month spread: groups by day
/// - Day spread: simple list
struct TaskListView: View {
    @Environment(JournalManager.self) private var journalManager
    let spread: DataModel.Spread
    let tasks: [DataModel.Task]
    let onTaskTap: (DataModel.Task) -> Void
    let onTaskComplete: (DataModel.Task) -> Void
    let onTaskMigrate: (DataModel.Task) -> Void

    var body: some View {
        if tasks.isEmpty {
            emptyStateView
        } else {
            List {
                ForEach(groupedTasks, id: \.key) { group in
                    Section {
                        ForEach(group.tasks, id: \.id) { task in
                            let status = journalManager.taskStatus(task, for: spread.period, date: spread.date) ?? task.status
                            let canMigrate = canMigrateTask(task)

                            TaskRowView(
                                task: task,
                                status: status,
                                canMigrate: canMigrate,
                                onTap: { onTaskTap(task) },
                                onComplete: { completeTask(task) },
                                onMigrate: { onTaskMigrate(task) }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: FolderTabDesign.taskRowHorizontalPadding,
                                bottom: 0,
                                trailing: FolderTabDesign.taskRowHorizontalPadding
                            ))
                        }
                    } header: {
                        if let headerText = group.header {
                            Text(headerText)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("No tasks")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Add a task to this spread")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grouping Logic

    private struct TaskGroup: Identifiable {
        let key: String
        let header: String?
        let tasks: [DataModel.Task]
        var id: String { key }
    }

    private var groupedTasks: [TaskGroup] {
        let calendar = journalManager.calendar

        switch spread.period {
        case .year:
            // Group by month
            return groupTasksByMonth(tasks, calendar: calendar)
        case .month:
            // Group by day
            return groupTasksByDay(tasks, calendar: calendar)
        case .multiday:
            // Group by day for multiday spreads
            return groupTasksByDay(tasks, calendar: calendar)
        case .week, .day:
            // Simple list, no grouping
            return [TaskGroup(key: "all", header: nil, tasks: sortedTasks)]
        }
    }

    private var sortedTasks: [DataModel.Task] {
        tasks.sorted { $0.date < $1.date }
    }

    private func groupTasksByMonth(_ tasks: [DataModel.Task], calendar: Calendar) -> [TaskGroup] {
        let grouped = Dictionary(grouping: tasks) { task in
            calendar.component(.month, from: task.date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        return grouped.keys.sorted().map { month in
            let monthDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: spread.date), month: month))!
            let header = formatter.string(from: monthDate)
            let tasksInMonth = (grouped[month] ?? []).sorted { $0.date < $1.date }
            return TaskGroup(key: "month-\(month)", header: header, tasks: tasksInMonth)
        }
    }

    private func groupTasksByDay(_ tasks: [DataModel.Task], calendar: Calendar) -> [TaskGroup] {
        let grouped = Dictionary(grouping: tasks) { task in
            calendar.startOfDay(for: task.date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"

        return grouped.keys.sorted().map { dayDate in
            let header = formatter.string(from: dayDate)
            let tasksOnDay = (grouped[dayDate] ?? []).sorted { $0.date < $1.date }
            return TaskGroup(key: "day-\(dayDate)", header: header, tasks: tasksOnDay)
        }
    }

    // MARK: - Actions

    private func canMigrateTask(_ task: DataModel.Task) -> Bool {
        // A task can be migrated if there's a child spread to migrate to
        // For now, check if the task has an open status on this spread
        let status = journalManager.taskStatus(task, for: spread.period, date: spread.date)
        return status == .open
    }

    private func completeTask(_ task: DataModel.Task) {
        // Update the task's status on this spread's assignment
        if let index = task.assignments.firstIndex(where: {
            $0.matches(period: spread.period, date: spread.date, calendar: journalManager.calendar)
        }) {
            task.assignments[index].status = .complete
        }
        task.status = .complete
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    let tasks = [
        DataModel.Task(title: "Task for Feb 1", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!, period: .day, status: .open),
        DataModel.Task(title: "Task for Feb 5", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!, period: .day, status: .open),
        DataModel.Task(title: "Completed task", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!, period: .day, status: .complete),
        DataModel.Task(title: "Task for Feb 10", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!, period: .day, status: .open),
    ]

    return TaskListView(
        spread: DataModel.Spread(period: .month, date: spreadDate),
        tasks: tasks,
        onTaskTap: { _ in },
        onTaskComplete: { _ in },
        onTaskMigrate: { _ in }
    )
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
