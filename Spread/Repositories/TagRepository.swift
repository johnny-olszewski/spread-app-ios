import Foundation

/// Protocol defining persistence operations for tags.
///
/// Implementations handle CRUD operations for `DataModel.Tag` entities.
@MainActor
protocol TagRepository: Sendable {
    /// Retrieves all active tags from storage.
    func getTags() async -> [DataModel.Tag]

    /// Saves a tag to storage.
    ///
    /// - Parameter tag: The tag to save.
    /// - Throws: An error if the save operation fails.
    func save(_ tag: DataModel.Tag) async throws

    /// Deletes a tag from storage.
    ///
    /// Implementations should remove the tag from all associated tasks and notes
    /// before deleting the tag entity.
    ///
    /// - Parameter tag: The tag to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ tag: DataModel.Tag) async throws
}
