//
//  MigratedTasksSection.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// A collapsible section showing tasks that were migrated OUT of this spread.
/// Displays grayed out with migration icon and shows destination spread info.
struct MigratedTasksSection: View {
    @Environment(JournalManager.self) private var journalManager
    let spread: DataModel.Spread
    let migratedTasks: [DataModel.Task]
    let onTaskTap: (DataModel.Task) -> Void

    @State private var isExpanded = false

    var body: some View {
        if !migratedTasks.isEmpty {
            VStack(spacing: 0) {
                Divider()

                // Header button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)

                        Text("Migrated (\(migratedTasks.count))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expandable task list
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(migratedTasks, id: \.id) { task in
                            MigratedTaskRowView(
                                task: task,
                                destinationDescription: migrationDestination(for: task),
                                onTap: { onTaskTap(task) }
                            )

                            if task.id != migratedTasks.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    // Transparent background to show dot grid through
                }
            }
        }
    }

    /// Finds where the task was migrated to after this spread
    private func migrationDestination(for task: DataModel.Task) -> String? {
        let calendar = journalManager.calendar

        // Find all assignments after this spread (smaller period = more specific)
        let laterAssignments = task.assignments.filter { assignment in
            // Find assignments that are "after" this spread in the migration chain
            // This means assignments with smaller periods OR same period but different date
            if assignment.period.rawValue < spread.period.rawValue {
                return true
            }
            return false
        }

        // Get the most recent (smallest period) assignment
        if let destination = laterAssignments.sorted(by: { $0.period.rawValue < $1.period.rawValue }).first {
            return formatAssignment(period: destination.period, date: destination.date, calendar: calendar)
        }

        return nil
    }

    private func formatAssignment(period: DataModel.Spread.Period, date: Date, calendar: Calendar) -> String {
        switch period {
        case .year:
            let year = calendar.component(.year, from: date)
            return "\(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yy"
            return formatter.string(from: date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date) + "+"
        case .week:
            let week = calendar.component(.weekOfYear, from: date)
            return "Week \(week)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    let task1 = DataModel.Task(
        title: "Review proposal",
        date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
        period: .day,
        status: .migrated
    )
    task1.assignments = [
        DataModel.TaskAssignment(period: .month, date: spreadDate, status: .migrated),
        DataModel.TaskAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!, status: .open)
    ]

    let task2 = DataModel.Task(
        title: "Call client",
        date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!,
        period: .day,
        status: .migrated
    )
    task2.assignments = [
        DataModel.TaskAssignment(period: .month, date: spreadDate, status: .migrated),
        DataModel.TaskAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!, status: .open)
    ]

    return VStack {
        Spacer()

        MigratedTasksSection(
            spread: DataModel.Spread(period: .month, date: spreadDate),
            migratedTasks: [task1, task2],
            onTaskTap: { _ in }
        )
    }
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
