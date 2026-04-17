import Foundation

/// Reconciles a task's spread assignment against the set of currently existing spreads.
///
/// Called after a task is created or its preferred date/period changes. The reconciler
/// inspects the task's `date` and `period`, finds the best matching conventional spread
/// using `ConventionalSpreadService`, and updates `task.assignments` in-place so that
/// exactly one assignment is active (or none if no spread matches).
///
/// Assignment mutation rules:
/// - If the best spread already has an assignment, it is promoted to the current status
///   and all other non-migrated assignments are marked `.migrated`.
/// - If the best spread has no existing assignment, all non-migrated assignments are marked
///   `.migrated` and a new assignment for the destination is appended.
/// - If no matching spread exists, all non-migrated assignments are marked `.migrated`
///   (the task lands in the Inbox).
@MainActor
protocol TaskAssignmentReconciler {
    /// Updates the task's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `task.assignments` in-place. Does not persist; callers must save the task afterward.
    ///
    /// - Parameters:
    ///   - task: The task whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread]
    )
}

/// Reconciles a note's spread assignment against the set of currently existing spreads.
///
/// Mirrors `TaskAssignmentReconciler` for notes. Notes always land on a spread with
/// `.active` status (they do not carry a completion state at the assignment level).
@MainActor
protocol NoteAssignmentReconciler {
    /// Updates the note's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `note.assignments` in-place. Does not persist; callers must save the note afterward.
    ///
    /// - Parameters:
    ///   - note: The note whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread]
    )
}

/// Standard implementation of `TaskAssignmentReconciler` using `ConventionalSpreadService`.
///
/// Finds the best spread for a task's preferred date/period and updates assignments to
/// reflect the result. When the task is complete, the destination assignment inherits
/// `.complete` status; otherwise it is set to `.open`.
@MainActor
struct StandardTaskAssignmentReconciler: TaskAssignmentReconciler {
    /// The calendar used for date normalization and spread matching.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread]
    ) {
        let destination = spreadService.findBestSpread(for: task, in: spreads)
        let destinationStatus = task.status == .complete ? DataModel.Task.Status.complete : task.status

        if let destination {
            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in task.assignments.indices where index != destinationIndex && task.assignments[index].status != .migrated {
                    task.assignments[index].status = .migrated
                }
                task.assignments[destinationIndex].status = destinationStatus
            } else {
                migrateActiveAssignmentsToHistory(task)
                task.assignments.append(
                    TaskAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: destinationStatus
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(task)
        }
    }

    /// Marks all non-migrated assignments on the task as `.migrated`.
    ///
    /// Used to archive the task's history before appending a new active assignment.
    private func migrateActiveAssignmentsToHistory(_ task: DataModel.Task) {
        for index in task.assignments.indices where task.assignments[index].status != .migrated {
            task.assignments[index].status = .migrated
        }
    }
}

/// Standard implementation of `NoteAssignmentReconciler` using `ConventionalSpreadService`.
///
/// Mirrors `StandardTaskAssignmentReconciler` for notes. Destination assignments always
/// receive `.active` status regardless of the note's current state.
@MainActor
struct StandardNoteAssignmentReconciler: NoteAssignmentReconciler {
    /// The calendar used for date normalization and spread matching.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread]
    ) {
        let destination = spreadService.findBestSpread(for: note, in: spreads)

        if let destination {
            if let destinationIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in note.assignments.indices where index != destinationIndex && note.assignments[index].status != .migrated {
                    note.assignments[index].status = .migrated
                }
                note.assignments[destinationIndex].status = .active
            } else {
                migrateActiveAssignmentsToHistory(note)
                note.assignments.append(
                    NoteAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: .active
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(note)
        }
    }

    /// Marks all non-migrated assignments on the note as `.migrated`.
    ///
    /// Used to archive the note's history before appending a new active assignment.
    private func migrateActiveAssignmentsToHistory(_ note: DataModel.Note) {
        for index in note.assignments.indices where note.assignments[index].status != .migrated {
            note.assignments[index].status = .migrated
        }
    }
}
