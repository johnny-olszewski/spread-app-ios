//
//  TaskEditView.swift
//  Bulleted
//
//  Created by Claude on 12/29/25.
//

import SwiftUI

/// Full task detail/edit view presented as a sheet.
/// Allows editing title, preferred date/period, and status.
struct TaskEditView: View {
    @Environment(JournalManager.self) private var journalManager
    @Environment(\.dismiss) private var dismiss

    let task: DataModel.Task
    let currentSpread: DataModel.Spread?
    let onSave: (DataModel.Task) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var preferredDate: Date
    @State private var preferredPeriod: DataModel.Spread.Period
    @State private var status: DataModel.Task.Status
    @State private var showingDeleteConfirmation = false

    init(
        task: DataModel.Task,
        currentSpread: DataModel.Spread?,
        onSave: @escaping (DataModel.Task) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.task = task
        self.currentSpread = currentSpread
        self.onSave = onSave
        self.onDelete = onDelete
        self._title = State(initialValue: task.title)
        self._preferredDate = State(initialValue: task.date)
        self._preferredPeriod = State(initialValue: task.period)
        self._status = State(initialValue: task.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Title
                Section("Task") {
                    TextField("Title", text: $title)
                }

                // Preferred Assignment
                Section("Preferred Assignment") {
                    Picker("Period", selection: $preferredPeriod) {
                        ForEach(assignablePeriods, id: \.self) { period in
                            Text(period.name).tag(period)
                        }
                    }

                    DatePicker(
                        "Date",
                        selection: $preferredDate,
                        displayedComponents: datePickerComponents
                    )
                }

                // Status
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(editableStatuses, id: \.self) { status in
                            HStack {
                                StatusIcon(status: status)
                                Text(status.name)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Assignment History (in conventional mode)
                if journalManager.bujoMode == .convential && !task.assignments.isEmpty {
                    Section("Assignment History") {
                        ForEach(task.assignments, id: \.self) { assignment in
                            HStack {
                                StatusIcon(status: assignment.status, size: 14)
                                Text(formatAssignment(assignment))
                                    .font(.subheadline)
                                Spacer()
                                Text(assignment.status.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Migration (if available)
                if canMigrateToCurrentSpread {
                    Section {
                        Button {
                            migrateToCurrentSpread()
                        } label: {
                            Label("Migrate to Current Spread", systemImage: "arrow.right")
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Delete Task?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - Computed Properties

    private var assignablePeriods: [DataModel.Spread.Period] {
        // Only periods that can have tasks assigned
        DataModel.Spread.Period.allCases.filter { $0.canHaveTasksAssigned }
    }

    private var editableStatuses: [DataModel.Task.Status] {
        // Users can only set to open or complete (not migrated directly)
        [.open, .complete]
    }

    private var datePickerComponents: DatePicker.Components {
        switch preferredPeriod {
        case .year:
            return [.date] // Still show date picker for year context
        case .month:
            return [.date]
        case .multiday:
            return [.date]
        case .week:
            return [.date]
        case .day:
            return [.date]
        }
    }

    private var canMigrateToCurrentSpread: Bool {
        guard let spread = currentSpread else { return false }
        return journalManager.canMigrateTask(task, to: spread.period, date: spread.date)
    }

    // MARK: - Formatting

    private func formatAssignment(_ assignment: DataModel.TaskAssignment) -> String {
        let calendar = journalManager.calendar
        switch assignment.period {
        case .year:
            let year = calendar.component(.year, from: assignment.date)
            return "Year \(year)"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: assignment.date)
        case .multiday:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: assignment.date) + "+"
        case .week:
            let week = calendar.component(.weekOfYear, from: assignment.date)
            let year = calendar.component(.year, from: assignment.date)
            return "Week \(week), \(year)"
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: assignment.date)
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        task.title = title
        task.date = preferredDate
        task.period = preferredPeriod

        // Update the status on all non-migrated assignments
        for i in task.assignments.indices {
            if task.assignments[i].status != .migrated {
                task.assignments[i].status = status
            }
        }
        task.status = status

        onSave(task)
    }

    private func migrateToCurrentSpread() {
        guard let spread = currentSpread,
              let openAssignment = task.assignments.first(where: { $0.status == .open }) else {
            return
        }

        journalManager.migrateTask(
            task,
            from: openAssignment.period,
            sourceDate: openAssignment.date,
            to: spread.period,
            destDate: spread.date
        )

        dismiss()
    }
}


#Preview {
    let calendar = Calendar.current
    let today = Date()

    let task = DataModel.Task(
        title: "Sample task",
        date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
        period: .day,
        status: .open
    )
    task.assignments = [
        DataModel.TaskAssignment(
            period: .month,
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
            status: .migrated
        ),
        DataModel.TaskAssignment(
            period: .day,
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
            status: .open
        )
    ]

    return TaskEditView(
        task: task,
        currentSpread: DataModel.Spread(
            period: .month,
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        ),
        onSave: { _ in },
        onDelete: {}
    )
    .environment(JournalManager(
        calendar: calendar,
        today: today,
        bujoMode: .convential,
        spreadRepository: mock_SpreadRepository(calendar: calendar, today: today),
        taskRepository: mock_TaskRepository(calendar: calendar, today: today)
    ))
}
