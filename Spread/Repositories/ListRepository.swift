import Foundation

/// Protocol defining persistence operations for lists.
///
/// Implementations handle CRUD operations for `DataModel.List` entities.
@MainActor
protocol ListRepository: Sendable {
    /// Retrieves all active lists from storage.
    func getLists() async -> [DataModel.List]

    /// Saves a list to storage.
    ///
    /// - Parameter list: The list to save.
    /// - Throws: An error if the save operation fails.
    func save(_ list: DataModel.List) async throws

    /// Deletes a list from storage.
    ///
    /// Implementations should nil out the `list` relationship on all associated
    /// tasks and notes before deleting the list entity.
    ///
    /// - Parameter list: The list to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ list: DataModel.List) async throws
}
