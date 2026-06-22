import Foundation

/// Protocol defining change-aware persistence operations for tasks.
///
/// Unlike `TaskRepository`, `save` takes an explicit `EntityChange` describing the task's
/// pre-mutation assignments/tags so the repository can diff for the sync outbox without
/// re-fetching prior state from disk.
///
/// - Note: `ChangeAware` is a temporary qualifier needed only while this protocol coexists
///   with the legacy `TaskRepository`. Once SPRD-249's cutover deletes `TaskRepository` and
///   `SwiftDataTaskRepository`, rename this to `TaskRepository` (see SPRD-245's renaming plan).
@MainActor
protocol ChangeAwareTaskRepository: Sendable {
    /// Retrieves all tasks from storage.
    func getTasks() async -> [DataModel.Task]

    /// Saves a task, diffing the sync outbox against the caller-supplied pre-mutation state.
    ///
    /// - Parameters:
    ///   - task: The task to save, already mutated to its new state.
    ///   - change: The task's identity/assignments/tags as they existed before mutation.
    /// - Throws: An error if the save operation fails.
    func save(_ task: DataModel.Task, change: EntityChange<TaskAssignment>) async throws

    /// Saves multiple tasks in a single persistence commit, each diffed against its own
    /// caller-supplied pre-mutation state.
    ///
    /// - Parameter requests: The tasks to save, paired with their pre-mutation change descriptors.
    /// - Throws: An error if the save operation fails.
    func saveAll(_ requests: [TaskSaveRequest]) async throws

    /// Deletes a task from storage.
    ///
    /// - Parameter task: The task to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ task: DataModel.Task) async throws
}
