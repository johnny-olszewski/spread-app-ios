//
//  MigrationSelectionView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A view for batch migration selection.
/// Shows list of eligible tasks with checkboxes for selective migration.
struct MigrationSelectionView: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.dismiss) private var dismiss

    let spread: DataModel.Spread
    let eligibleTasks: [DataModel.Task]
    let onMigrate: ([DataModel.Task]) -> Void

    @State private var selectedTaskIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header info
                headerView

                // Task list
                List(eligibleTasks, id: \.id, selection: $selectedTaskIds) { task in
                    TaskSelectionRow(
                        task: task,
                        isSelected: selectedTaskIds.contains(task.id),
                        currentAssignment: currentAssignment(for: task)
                    ) {
                        toggleSelection(task)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Migrate Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Migrate (\(selectedTaskIds.count))") {
                        migrateSelected()
                    }
                    .disabled(selectedTaskIds.isEmpty)
                }
            }
            .onAppear {
                // Select all by default
                selectedTaskIds = Set(eligibleTasks.map(\.id))
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Migrate to \(spreadDescription)")
                .font(.headline)

            Text("Select tasks to migrate from parent spreads")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Select All") {
                    selectedTaskIds = Set(eligibleTasks.map(\.id))
                }
                .font(.caption)

                Button("Deselect All") {
                    selectedTaskIds = []
                }
                .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
    }

    private var spreadDescription: String {
        let calendar = journalManager.calendar
        switch spread.period {
        case .year:
            let year = calendar.component(.year, from: spread.date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: spread.date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: spread.date) + "+"
        case .week:
            let week = calendar.component(.weekOfYear, from: spread.date)
            return "Week \(week)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: spread.date)
        }
    }

    // MARK: - Helpers

    private func currentAssignment(for task: DataModel.Task) -> String? {
        guard let openAssignment = task.assignments.first(where: { $0.status == .open }) else {
            return nil
        }

        let calendar = journalManager.calendar
        switch openAssignment.period {
        case .year:
            let year = calendar.component(.year, from: openAssignment.date)
            return "Year \(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: openAssignment.date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: openAssignment.date) + "+"
        case .week:
            let week = calendar.component(.weekOfYear, from: openAssignment.date)
            return "Week \(week)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: openAssignment.date)
        }
    }

    private func toggleSelection(_ task: DataModel.Task) {
        if selectedTaskIds.contains(task.id) {
            selectedTaskIds.remove(task.id)
        } else {
            selectedTaskIds.insert(task.id)
        }
    }

    private func migrateSelected() {
        let tasksToMigrate = eligibleTasks.filter { selectedTaskIds.contains($0.id) }
        onMigrate(tasksToMigrate)
        dismiss()
    }
}

/// A row in the migration selection list
private struct TaskSelectionRow: View {
    let task: DataModel.Task
    let isSelected: Bool
    let currentAssignment: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                // Task info
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let assignment = currentAssignment {
                        Text("Currently on: \(assignment)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    let tasks = [
        DataModel.Task(title: "Task from year", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!, period: .day, status: .open),
        DataModel.Task(title: "Another task", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!, period: .day, status: .open),
        DataModel.Task(title: "Third task", date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!, period: .day, status: .open),
    ]

    // Add assignments
    tasks[0].assignments = [
        DataModel.TaskAssignment(period: .year, date: calendar.date(from: DateComponents(year: 2026))!, status: .open)
    ]
    tasks[1].assignments = [
        DataModel.TaskAssignment(period: .year, date: calendar.date(from: DateComponents(year: 2026))!, status: .open)
    ]
    tasks[2].assignments = [
        DataModel.TaskAssignment(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: 1))!, status: .open)
    ]

    return MigrationSelectionView(
        spread: DataModel.Spread(period: .month, date: spreadDate),
        eligibleTasks: tasks,
        onMigrate: { tasks in
            print("Migrating \(tasks.count) tasks")
        }
    )
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
