import Foundation

/// Protocol defining persistence operations for tasks.
///
/// Implementations handle CRUD operations for `DataModel.Task` entities.
/// SwiftData implementation provided in SPRD-5.
@MainActor
protocol TaskRepository: Sendable {
    /// Retrieves all tasks from storage.
    func getTasks() async -> [DataModel.Task]

    /// Saves a task to storage.
    ///
    /// - Parameter task: The task to save.
    /// - Throws: An error if the save operation fails.
    func save(_ task: DataModel.Task) async throws

    /// Deletes a task from storage.
    ///
    /// - Parameter task: The task to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ task: DataModel.Task) async throws
}
