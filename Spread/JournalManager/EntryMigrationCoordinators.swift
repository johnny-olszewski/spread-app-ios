import Foundation

/// Coordinates explicit task migration workflows between spreads or from Inbox.
///
/// Handles both single-task and batch migrations. Each migration updates the task's
/// assignments in-place (marking the source as `.migrated` and activating the destination),
/// persists the change via the task repository, and returns the refreshed task list.
///
/// Does not rebuild the journal data model — callers (`JournalManager`) are responsible
/// for calling `buildDataModel()` and incrementing `dataVersion` after the migration.
@MainActor
protocol TaskMigrationCoordinator {
    /// Moves a single task from a source (spread or Inbox) to a destination spread.
    ///
    /// - Marks the source assignment `.migrated` (skipped when source is Inbox).
    /// - Creates or updates the destination assignment to `.open`.
    /// - Resets `task.status` to `.open`.
    /// - Persists the task and returns the refreshed full task list.
    ///
    /// - Parameters:
    ///   - task: The task to move.
    ///   - sourceKey: The source — Inbox or a specific spread.
    ///   - destination: The spread to move the task to.
    ///   - calendar: Calendar used for assignment date matching.
    /// - Returns: The full updated task list from the repository.
    /// - Throws: `MigrationError` if the task is cancelled, the destination is not assignable,
    ///   or the source assignment cannot be found.
    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Task]

    /// Migrates multiple open tasks from one spread to another in a single batch.
    ///
    /// Cancelled tasks are silently skipped. Tasks without a matching source assignment
    /// are also skipped. For each eligible task:
    /// - The source assignment is marked `.migrated`.
    /// - A destination assignment is created or updated to `.open`.
    /// - `task.status` is reset to `.open`.
    ///
    /// - Parameters:
    ///   - tasks: The tasks to migrate.
    ///   - source: The spread to migrate tasks away from.
    ///   - destination: The target spread.
    ///   - calendar: Calendar used for assignment date matching.
    /// - Returns: A `TaskBatchMigrationResult` with the refreshed task list and a flag
    ///   indicating whether any tasks were actually migrated.
    /// - Throws: `MigrationError.destinationNotAssignable` if the destination cannot accept assignments.
    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult
}

/// Coordinates explicit note migration workflows between spreads.
///
/// Notes support explicit-only migration (no batch). The source assignment is marked
/// `.migrated` and a new `.active` assignment is created on the destination.
@MainActor
protocol NoteMigrationCoordinator {
    /// Migrates a note from one spread to another.
    ///
    /// - Marks the source assignment `.migrated`.
    /// - Creates or updates the destination assignment to `.active`.
    /// - Persists the note and returns the refreshed full note list.
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - source: The spread to migrate from.
    ///   - destination: The spread to migrate to.
    ///   - calendar: Calendar used for assignment date matching.
    /// - Returns: The full updated note list from the repository.
    /// - Throws: `MigrationError` if the destination is not assignable or the source assignment
    ///   cannot be found.
    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Note]
}

/// The result of a batch task migration operation.
struct TaskBatchMigrationResult {
    /// The full, refreshed task list after the migration (or unchanged if nothing migrated).
    let tasks: [DataModel.Task]

    /// `true` if at least one task was successfully migrated; `false` if all were skipped.
    let migratedAny: Bool
}

/// Standard implementation of `TaskMigrationCoordinator`.
///
/// Persists all changes through `taskRepository` and logs each migration event.
@MainActor
struct StandardTaskMigrationCoordinator: TaskMigrationCoordinator {
    /// The repository used to persist and retrieve tasks.
    let taskRepository: any TaskRepository
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter

    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Task] {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        switch sourceKey.kind {
        case .inbox:
            break
        case .spread(_, let sourcePeriod, let sourceDate):
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: sourcePeriod, date: sourceDate, calendar: calendar)
            }) else {
                throw MigrationError.noSourceAssignment
            }
            task.assignments[sourceIndex].status = .migrated
        }

        if let destinationIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            task.assignments[destinationIndex].status = .open
        } else {
            task.assignments.append(
                TaskAssignment(
                    period: destination.period,
                    date: destination.date,
                    status: .open
                )
            )
        }

        task.status = .open
        try await taskRepository.save(task)

        let sourceDescription: String = switch sourceKey.kind {
        case .inbox:
            "inbox"
        case .spread(_, let period, _):
            period.rawValue
        }
        logger.info("Migration performed: task \(task.id) from \(sourceDescription) to \(destination.period.rawValue)")
        return await taskRepository.getTasks()
    }

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult {
        guard !tasks.isEmpty else {
            return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedAny: false)
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        var migratedAny = false

        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: source.period, date: source.date, calendar: calendar)
            }) else {
                continue
            }

            task.assignments[sourceIndex].status = .migrated

            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                task.assignments[destinationIndex].status = .open
            } else {
                task.assignments.append(
                    TaskAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: .open
                    )
                )
            }

            task.status = .open
            try await taskRepository.save(task)
            migratedAny = true
        }

        if migratedAny {
            logger.info(
                "Batch migration performed: \(tasks.count) task(s) from \(source.period.rawValue) to \(destination.period.rawValue)"
            )
        }

        return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedAny: migratedAny)
    }
}

/// Standard implementation of `NoteMigrationCoordinator`.
///
/// Persists all changes through `noteRepository` and logs each migration event.
@MainActor
struct StandardNoteMigrationCoordinator: NoteMigrationCoordinator {
    /// The repository used to persist and retrieve notes.
    let noteRepository: any NoteRepository
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter

    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Note] {
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        guard let sourceIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: source.period, date: source.date, calendar: calendar)
        }) else {
            throw MigrationError.noSourceAssignment
        }

        note.assignments[sourceIndex].status = .migrated

        if let destinationIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            note.assignments[destinationIndex].status = .active
        } else {
            note.assignments.append(
                NoteAssignment(
                    period: destination.period,
                    date: destination.date,
                    status: .active
                )
            )
        }

        try await noteRepository.save(note)
        logger.info("Migration performed: note \(note.id) from \(source.period.rawValue) to \(destination.period.rawValue)")
        return await noteRepository.getNotes()
    }
}
