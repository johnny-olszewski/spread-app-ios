import struct Foundation.UUID

/// Protocol defining persistence operations for spreads.
///
/// Implementations handle CRUD operations for `DataModel.Spread` entities.
/// SwiftData implementation provided in SPRD-5.
@MainActor
protocol SpreadRepository: Sendable {
    /// Retrieves all spreads from storage.
    func getSpreads() async -> [DataModel.Spread]

    /// Saves a spread to storage.
    ///
    /// - Parameter spread: The spread to save.
    /// - Throws: An error if the save operation fails.
    func save(_ spread: DataModel.Spread) async throws

    /// Deletes a spread from storage.
    ///
    /// - Parameter spread: The spread to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ spread: DataModel.Spread) async throws
}
