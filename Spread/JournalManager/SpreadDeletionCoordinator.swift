import Foundation

/// Captures the assignment reassignment plan for a single task when its spread is deleted.
///
/// When a spread is deleted, each task assigned to it must either move to a parent spread
/// (if one exists) or fall back to the Inbox. This value type records exactly what needs
/// to happen so the coordinator can apply changes atomically without re-querying the model.
struct TaskSpreadDeletionPlan: Sendable {
    /// The ID of the task this plan applies to.
    let taskID: UUID

    /// Index into `task.assignments` for the assignment on the spread being deleted.
    ///
    /// This assignment's status will be set to `.migrated` during execution.
    let sourceAssignmentIndex: Int

    /// Index into `task.assignments` for an existing assignment on the parent spread, if any.
    ///
    /// When non-nil, the existing parent assignment's status is updated to `preservedStatus`.
    /// When nil, a new assignment (`replacementAssignment`) is appended instead.
    let replacementAssignmentIndex: Int?

    /// A new assignment to append to the task for the parent spread, if no existing one was found.
    ///
    /// `nil` when `replacementAssignmentIndex` is set (the parent already has an assignment)
    /// or when there is no parent spread (the task goes to Inbox).
    let replacementAssignment: TaskAssignment?

    /// The status to carry over to the replacement assignment (e.g., `.open` or `.complete`).
    ///
    /// Ensures the task's status on the parent spread reflects what it had on the deleted spread.
    let preservedStatus: DataModel.Task.Status
}

/// Captures the assignment reassignment plan for a single note when its spread is deleted.
///
/// Mirrors `TaskSpreadDeletionPlan` for notes. Note assignments use `NoteAssignment.Status`
/// rather than `DataModel.Task.Status`.
struct NoteSpreadDeletionPlan: Sendable {
    /// The ID of the note this plan applies to.
    let noteID: UUID

    /// Index into `note.assignments` for the assignment on the spread being deleted.
    let sourceAssignmentIndex: Int

    /// Index into `note.assignments` for an existing assignment on the parent spread, if any.
    let replacementAssignmentIndex: Int?

    /// A new assignment to append for the parent spread, or `nil` when going to Inbox or
    /// when the parent already has an assignment.
    let replacementAssignment: NoteAssignment?

    /// The status to carry over to the replacement assignment.
    let preservedStatus: DataModel.Note.Status
}

/// A complete plan for deleting a spread and reassigning all of its entries.
///
/// Built by `SpreadDeletionPlanner` and executed by `SpreadDeletionCoordinator`.
/// Separating planning from execution makes the outcome inspectable before any
/// mutations are applied (useful for presenting confirmation UIs).
struct SpreadDeletionPlan: Sendable {
    /// The spread to be deleted.
    let spread: DataModel.Spread

    /// The nearest ancestor spread that will receive reassigned entries, if any.
    ///
    /// The planner walks up the period hierarchy (day → month → year) and picks the
    /// first existing parent spread. `nil` means entries will fall to the Inbox.
    let parentSpread: DataModel.Spread?

    /// Per-task reassignment plans for tasks assigned to `spread`.
    let taskPlans: [TaskSpreadDeletionPlan]

    /// Per-note reassignment plans for notes assigned to `spread`.
    let notePlans: [NoteSpreadDeletionPlan]
}

/// The outcome of executing a spread deletion.
///
/// Contains the plan that was applied along with the refreshed repository state,
/// so callers can update their in-memory collections atomically.
struct SpreadDeletionResult {
    /// The plan that was applied to produce this result.
    let plan: SpreadDeletionPlan

    /// The full spread list after the deletion.
    let spreads: [DataModel.Spread]

    /// The full task list after all assignments were reassigned.
    let tasks: [DataModel.Task]

    /// The full note list after all assignments were reassigned.
    let notes: [DataModel.Note]
}

/// Builds a `SpreadDeletionPlan` for a given spread without applying any mutations.
///
/// Separating planning from execution keeps the coordinator's logic simple and makes
/// it straightforward to test the reassignment strategy independently.
@MainActor
protocol SpreadDeletionPlanner {
    /// Computes the reassignment plan for deleting the specified spread.
    ///
    /// - Parameters:
    ///   - spread: The spread to be deleted.
    ///   - spreads: All existing spreads (used to find the parent spread).
    ///   - tasks: All tasks (only those assigned to `spread` are planned).
    ///   - notes: All notes (only those assigned to `spread` are planned).
    /// - Returns: A `SpreadDeletionPlan` describing every assignment mutation required.
    func makePlan(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) -> SpreadDeletionPlan
}

/// Executes a spread deletion by applying the plan, persisting changes, and returning
/// the refreshed repository state.
///
/// Entries are never deleted — only their assignments are mutated. The spread record
/// itself is removed from the repository last, after all entry mutations succeed.
@MainActor
protocol SpreadDeletionCoordinator {
    /// Deletes a spread and reassigns all of its entries to a parent spread or Inbox.
    ///
    /// - Parameters:
    ///   - spread: The spread to delete.
    ///   - spreads: All existing spreads (passed to the planner).
    ///   - tasks: All tasks (passed to the planner for reassignment).
    ///   - notes: All notes (passed to the planner for reassignment).
    /// - Returns: A `SpreadDeletionResult` with the plan and refreshed repository state.
    /// - Throws: Repository errors if any persistence operation fails.
    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> SpreadDeletionResult
}

/// Standard implementation of `SpreadDeletionPlanner`.
///
/// Finds the nearest ancestor spread by walking up the period hierarchy and builds
/// per-entry plans that preserve each entry's current assignment status.
@MainActor
struct StandardSpreadDeletionPlanner: SpreadDeletionPlanner {
    /// The calendar used for date normalization when matching spreads in the hierarchy.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func makePlan(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) -> SpreadDeletionPlan {
        let parentSpread = spread.period == .multiday ? nil : findParentSpread(for: spread, in: spreads)

        let taskPlans = tasks.compactMap { task in
            makeTaskPlan(
                for: task,
                deleting: spread,
                parentSpread: parentSpread,
                spreads: spreads
            )
        }

        let notePlans = notes.compactMap { note in
            makeNotePlan(
                for: note,
                deleting: spread,
                parentSpread: parentSpread,
                spreads: spreads
            )
        }

        return SpreadDeletionPlan(
            spread: spread,
            parentSpread: parentSpread,
            taskPlans: taskPlans,
            notePlans: notePlans
        )
    }

    private func findParentSpread(
        for spread: DataModel.Spread,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        var currentPeriod: Period? = spread.period.parentPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(spread.date, calendar: calendar)
            if let parentSpread = spreads.first(where: { existingSpread in
                existingSpread.period == period &&
                existingSpread.period.normalizeDate(existingSpread.date, calendar: calendar) == normalizedDate
            }) {
                return parentSpread
            }
            currentPeriod = period.parentPeriod
        }

        return nil
    }

    private func makeTaskPlan(
        for task: DataModel.Task,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> TaskSpreadDeletionPlan? {
        guard let sourceAssignmentIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(spread: spread, calendar: calendar)
        }) else {
            return nil
        }

        let preservedStatus = task.assignments[sourceAssignmentIndex].status
        let replacementSpread = replacementSpread(
            for: task,
            deleting: spread,
            parentSpread: parentSpread,
            spreads: spreads
        )
        let replacementAssignmentIndex = replacementSpread.flatMap { parent in
            task.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: parent, calendar: calendar)
            })
        }

        let replacementAssignment = replacementSpread.flatMap { parent -> TaskAssignment? in
            guard replacementAssignmentIndex == nil else { return nil }
            return TaskAssignment(
                period: parent.period,
                date: parent.date,
                spreadID: parent.period == .multiday ? parent.id : nil,
                status: preservedStatus
            )
        }

        return TaskSpreadDeletionPlan(
            taskID: task.id,
            sourceAssignmentIndex: sourceAssignmentIndex,
            replacementAssignmentIndex: replacementAssignmentIndex,
            replacementAssignment: replacementAssignment,
            preservedStatus: preservedStatus
        )
    }

    private func makeNotePlan(
        for note: DataModel.Note,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> NoteSpreadDeletionPlan? {
        guard let sourceAssignmentIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(spread: spread, calendar: calendar)
        }) else {
            return nil
        }

        let preservedStatus = note.assignments[sourceAssignmentIndex].status
        let replacementSpread = replacementSpread(
            for: note,
            deleting: spread,
            parentSpread: parentSpread,
            spreads: spreads
        )
        let replacementAssignmentIndex = replacementSpread.flatMap { parent in
            note.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: parent, calendar: calendar)
            })
        }

        let replacementAssignment = replacementSpread.flatMap { parent -> NoteAssignment? in
            guard replacementAssignmentIndex == nil else { return nil }
            return NoteAssignment(
                period: parent.period,
                date: parent.date,
                spreadID: parent.period == .multiday ? parent.id : nil,
                status: preservedStatus
            )
        }

        return NoteSpreadDeletionPlan(
            noteID: note.id,
            sourceAssignmentIndex: sourceAssignmentIndex,
            replacementAssignmentIndex: replacementAssignmentIndex,
            replacementAssignment: replacementAssignment,
            preservedStatus: preservedStatus
        )
    }

    private func replacementSpread(
        for task: DataModel.Task,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        if spread.period != .multiday {
            return parentSpread
        }

        let fallbackPeriod: Period = task.period == .multiday ? .month : task.period
        return spreadService.findBestSpread(
            preferredDate: task.date,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }

    private func replacementSpread(
        for note: DataModel.Note,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        if spread.period != .multiday {
            return parentSpread
        }

        let fallbackPeriod: Period = note.period == .multiday ? .month : note.period
        return spreadService.findBestSpread(
            preferredDate: note.date,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }
}

/// Standard implementation of `SpreadDeletionCoordinator`.
///
/// Delegates plan creation to `SpreadDeletionPlanner`, then applies each task and note
/// plan sequentially before deleting the spread record. All persistence goes through
/// the respective repositories.
@MainActor
struct StandardSpreadDeletionCoordinator: SpreadDeletionCoordinator {
    /// The planner used to compute the reassignment plan before any mutations are applied.
    let planner: any SpreadDeletionPlanner
    /// Repository for deleting the spread record and refreshing the spread list.
    let spreadRepository: any SpreadRepository
    /// Repository for saving reassigned tasks and refreshing the task list.
    let taskRepository: any TaskRepository
    /// Repository for saving reassigned notes and refreshing the note list.
    let noteRepository: any NoteRepository
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter

    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> SpreadDeletionResult {
        let plan = planner.makePlan(
            for: spread,
            spreads: spreads,
            tasks: tasks,
            notes: notes
        )

        for taskPlan in plan.taskPlans {
            guard let task = tasks.first(where: { $0.id == taskPlan.taskID }) else { continue }
            task.assignments[taskPlan.sourceAssignmentIndex].status = .migrated
            if let replacementAssignmentIndex = taskPlan.replacementAssignmentIndex {
                task.assignments[replacementAssignmentIndex].status = taskPlan.preservedStatus
            } else if let replacementAssignment = taskPlan.replacementAssignment {
                task.assignments.append(replacementAssignment)
            }
            try await taskRepository.save(task)
        }

        for notePlan in plan.notePlans {
            guard let note = notes.first(where: { $0.id == notePlan.noteID }) else { continue }
            note.assignments[notePlan.sourceAssignmentIndex].status = .migrated
            if let replacementAssignmentIndex = notePlan.replacementAssignmentIndex {
                note.assignments[replacementAssignmentIndex].status = notePlan.preservedStatus
            } else if let replacementAssignment = notePlan.replacementAssignment {
                note.assignments.append(replacementAssignment)
            }
            try await noteRepository.save(note)
        }

        try await spreadRepository.delete(spread)
        logger.info("Spread deleted: \(spread.period.rawValue) spread \(spread.id)")

        return SpreadDeletionResult(
            plan: plan,
            spreads: await spreadRepository.getSpreads(),
            tasks: await taskRepository.getTasks(),
            notes: await noteRepository.getNotes()
        )
    }
}
