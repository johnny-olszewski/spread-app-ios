import struct Foundation.UUID

/// Protocol defining persistence operations for collections.
///
/// Implementations handle CRUD operations for `DataModel.Collection` entities.
/// SwiftData implementation provided in SPRD-39.
@MainActor
protocol CollectionRepository: Sendable {
    /// Retrieves all collections from storage.
    func getCollections() async -> [DataModel.Collection]

    /// Saves a collection to storage.
    ///
    /// - Parameter collection: The collection to save.
    /// - Throws: An error if the save operation fails.
    func save(_ collection: DataModel.Collection) async throws

    /// Deletes a collection from storage.
    ///
    /// - Parameter collection: The collection to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ collection: DataModel.Collection) async throws
}
