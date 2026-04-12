import Foundation

/// The result of a task creation operation.
///
/// Returns both the newly created task and the full refreshed task list so that
/// callers can update their in-memory state atomically.
struct TaskMutationResult {
    /// The task that was just created.
    let task: DataModel.Task
    /// The full task list from the repository after the creation.
    let tasks: [DataModel.Task]
}

/// The result of a note creation operation.
///
/// Returns both the newly created note and the full refreshed note list so that
/// callers can update their in-memory state atomically.
struct NoteMutationResult {
    /// The note that was just created.
    let note: DataModel.Note
    /// The full note list from the repository after the creation.
    let notes: [DataModel.Note]
}

/// Coordinates task creation and preferred-date mutation workflows.
///
/// Encapsulates the rules for normalizing dates, reconciling spread assignments, and
/// persisting changes. All methods return the refreshed task list so callers can
/// replace their in-memory state in a single step.
@MainActor
protocol TaskMutationCoordinator {
    /// Creates a new open task and assigns it to the best matching spread.
    ///
    /// The date is normalized to the period before the task is created. Assignment
    /// reconciliation runs immediately so the task lands on the correct spread
    /// (or Inbox if none matches).
    ///
    /// - Parameters:
    ///   - title: The task title.
    ///   - date: The user's chosen date.
    ///   - period: The user's chosen period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The new task and the refreshed full task list.
    /// - Throws: Repository errors if persistence fails.
    func createTask(
        title: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskMutationResult

    /// Updates a task's preferred date and period, then re-reconciles its spread assignment.
    ///
    /// Normalizes the new date to the period, updates the task's `date` and `period`
    /// properties, runs assignment reconciliation, and persists the change.
    ///
    /// - Parameters:
    ///   - task: The task to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The full refreshed task list.
    /// - Throws: Repository errors if persistence fails.
    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task]

    /// Migrates a task to a new preferred date/period in traditional mode.
    ///
    /// Clears all existing assignments, updates the task's `date` and `period`, then
    /// attempts to create a single new assignment on the nearest matching conventional
    /// spread. Unlike conventional migration, this does not mark any source assignment
    /// as `.migrated` — the task's full assignment history is replaced.
    ///
    /// - Parameters:
    ///   - task: The task to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used to find the best conventional spread.
    /// - Returns: The full refreshed task list.
    /// - Throws: `MigrationError.taskCancelled` if the task is cancelled; repository errors
    ///   if persistence fails.
    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task]
}

/// Coordinates note creation and preferred-date mutation workflows.
///
/// Mirrors `TaskMutationCoordinator` for notes. Note assignments always use `.active` status.
@MainActor
protocol NoteMutationCoordinator {
    /// Creates a new note and assigns it to the best matching spread.
    ///
    /// The date is normalized to the period before the note is created. Assignment
    /// reconciliation runs immediately so the note lands on the correct spread
    /// (or Inbox if none matches).
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - content: The note body text.
    ///   - date: The user's chosen date.
    ///   - period: The user's chosen period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The new note and the refreshed full note list.
    /// - Throws: Repository errors if persistence fails.
    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteMutationResult

    /// Updates a note's preferred date and period, then re-reconciles its spread assignment.
    ///
    /// - Parameters:
    ///   - note: The note to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The full refreshed note list.
    /// - Throws: Repository errors if persistence fails.
    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note]

    /// Migrates a note to a new preferred date/period in traditional mode.
    ///
    /// Clears all existing assignments and creates a single new `.active` assignment
    /// on the nearest matching conventional spread (if one exists).
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used to find the best conventional spread.
    /// - Returns: The full refreshed note list.
    /// - Throws: Repository errors if persistence fails.
    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note]
}

/// Standard implementation of `TaskMutationCoordinator`.
///
/// Uses `TaskAssignmentReconciler` for spread assignment logic and `TraditionalSpreadService`
/// for traditional-mode migration. All persistence goes through `taskRepository`.
@MainActor
struct StandardTaskMutationCoordinator: TaskMutationCoordinator {
    /// The repository used to persist and retrieve tasks.
    let taskRepository: any TaskRepository
    /// Reconciler for updating task spread assignments after creation or date changes.
    let taskAssignmentReconciler: any TaskAssignmentReconciler
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter
    /// Calendar used for date normalization and service initialization.
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createTask(
        title: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let task = DataModel.Task(
            title: title,
            createdDate: .now,
            date: normalizedDate,
            period: period,
            status: .open,
            assignments: []
        )

        taskAssignmentReconciler.reconcilePreferredAssignment(for: task, in: spreads)
        try await taskRepository.save(task)
        return TaskMutationResult(task: task, tasks: await taskRepository.getTasks())
    }

    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
        taskAssignmentReconciler.reconcilePreferredAssignment(for: task, in: spreads)
        try await taskRepository.save(task)
        return await taskRepository.getTasks()
    }

    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task] {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
        task.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            task.assignments.append(
                TaskAssignment(
                    period: bestSpread.period,
                    date: bestSpread.date,
                    status: task.status == .complete ? .complete : .open
                )
            )
        }

        try await taskRepository.save(task)
        logger.info("Traditional migration: task \(task.id) → \(newPeriod.rawValue) \(normalizedDate)")
        return await taskRepository.getTasks()
    }
}

/// Standard implementation of `NoteMutationCoordinator`.
///
/// Uses `NoteAssignmentReconciler` for spread assignment logic and `TraditionalSpreadService`
/// for traditional-mode migration. All persistence goes through `noteRepository`.
@MainActor
struct StandardNoteMutationCoordinator: NoteMutationCoordinator {
    /// The repository used to persist and retrieve notes.
    let noteRepository: any NoteRepository
    /// Reconciler for updating note spread assignments after creation or date changes.
    let noteAssignmentReconciler: any NoteAssignmentReconciler
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter
    /// Calendar used for date normalization and service initialization.
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let note = DataModel.Note(
            title: title,
            content: content,
            date: normalizedDate,
            period: period,
            assignments: []
        )

        noteAssignmentReconciler.reconcilePreferredAssignment(for: note, in: spreads)
        try await noteRepository.save(note)
        return NoteMutationResult(note: note, notes: await noteRepository.getNotes())
    }

    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.date = normalizedDate
        note.period = newPeriod
        noteAssignmentReconciler.reconcilePreferredAssignment(for: note, in: spreads)
        try await noteRepository.save(note)
        return await noteRepository.getNotes()
    }

    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.date = normalizedDate
        note.period = newPeriod
        note.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            note.assignments.append(
                NoteAssignment(
                    period: bestSpread.period,
                    date: bestSpread.date,
                    status: .active
                )
            )
        }

        try await noteRepository.save(note)
        logger.info("Traditional migration: note \(note.id) → \(newPeriod.rawValue) \(normalizedDate)")
        return await noteRepository.getNotes()
    }
}

/// A lightweight closure-based adapter that bridges coordinator logging to `OSLog`.
///
/// Coordinators accept a `LoggerAdapter` rather than a direct `Logger` reference to keep
/// them decoupled from the specific subsystem/category configuration used by their owner.
/// `JournalManager` injects an adapter backed by its own `Logger` instance.
struct LoggerAdapter {
    /// Called with a formatted message string to emit an info-level log entry.
    let info: (String) -> Void
}
