import SwiftUI

/// Sheet for selecting tasks to migrate to a destination spread.
///
/// Shows a checkbox list of eligible tasks with select/deselect all controls.
/// All tasks are selected by default. Each row shows the task title and its
/// current assignment location for context.
struct MigrationSelectionSheet: View {

    // MARK: - Properties

    /// The destination spread to migrate tasks to.
    let destinationSpread: DataModel.Spread

    /// Eligible tasks that can be migrated.
    let eligibleTasks: [DataModel.Task]

    /// The calendar for date formatting.
    let calendar: Calendar

    /// Callback with the selected tasks to migrate.
    let onMigrate: ([DataModel.Task]) -> Void

    @Environment(\.dismiss) private var dismiss

    /// IDs of currently selected tasks.
    @State private var selectedTaskIds: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                List {
                    ForEach(eligibleTasks, id: \.id) { task in
                        TaskSelectionRow(
                            task: task,
                            isSelected: selectedTaskIds.contains(task.id),
                            currentAssignment: currentAssignmentLabel(for: task)
                        ) {
                            toggleSelection(task)
                        }
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

    // MARK: - Helpers

    private var spreadDescription: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch destinationSpread.period {
        case .year:
            let year = calendar.component(.year, from: destinationSpread.date)
            return "\(year)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: destinationSpread.date)
        case .day:
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: destinationSpread.date)
        case .multiday:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: destinationSpread.date) + "+"
        }
    }

    /// Returns a label describing the task's current open assignment location.
    private func currentAssignmentLabel(for task: DataModel.Task) -> String? {
        guard let openAssignment = task.assignments.first(where: { $0.status == .open }) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone

        switch openAssignment.period {
        case .year:
            let year = calendar.component(.year, from: openAssignment.date)
            return "Year \(year)"
        case .month:
            formatter.dateFormat = "MMM yyyy"
            return formatter.string(from: openAssignment.date)
        case .day:
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: openAssignment.date)
        case .multiday:
            formatter.dateFormat = "M/d"
            return formatter.string(from: openAssignment.date) + "+"
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

// MARK: - Task Selection Row

/// A row in the migration selection list with checkbox, title, and current location.
private struct TaskSelectionRow: View {

    let task: DataModel.Task
    let isSelected: Bool
    let currentAssignment: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

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

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!

    let tasks = [
        DataModel.Task(
            title: "Task from year",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
            period: .day,
            status: .open
        ),
        DataModel.Task(
            title: "Another task",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!,
            period: .day,
            status: .open
        ),
        DataModel.Task(
            title: "Third task",
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 15))!,
            period: .day,
            status: .open
        ),
    ]

    tasks[0].assignments = [
        TaskAssignment(period: .year, date: calendar.date(from: DateComponents(year: 2026))!, status: .open)
    ]
    tasks[1].assignments = [
        TaskAssignment(period: .year, date: calendar.date(from: DateComponents(year: 2026))!, status: .open)
    ]
    tasks[2].assignments = [
        TaskAssignment(period: .month, date: calendar.date(from: DateComponents(year: 2026, month: 1))!, status: .open)
    ]

    return MigrationSelectionSheet(
        destinationSpread: DataModel.Spread(period: .month, date: spreadDate, calendar: calendar),
        eligibleTasks: tasks,
        calendar: calendar,
        onMigrate: { tasks in }
    )
}
