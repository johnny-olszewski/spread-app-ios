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
    /// - Returns: The updated task and full updated task list from the repository.
    /// - Throws: `MigrationError` if the task is cancelled, the destination is not assignable,
    ///   or the source assignment cannot be found.
    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskListMutationResult

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

/// The result of a batch task migration operation.
struct TaskBatchMigrationResult {
    /// The full, refreshed task list after the migration (or unchanged if nothing migrated).
    let tasks: [DataModel.Task]

    /// The tasks that were actually migrated in this batch.
    let migratedTasks: [DataModel.Task]

    /// `true` if at least one task was successfully migrated; `false` if all were skipped.
    let migratedAny: Bool
}
