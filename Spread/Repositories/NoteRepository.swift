import struct Foundation.UUID

/// Protocol defining persistence operations for notes.
///
/// Implementations handle CRUD operations for `DataModel.Note` entities.
/// SwiftData implementation provided in SPRD-58.
@MainActor
protocol NoteRepository: Sendable {
    /// Retrieves all notes from storage.
    func getNotes() async -> [DataModel.Note]

    /// Saves a note to storage.
    ///
    /// - Parameter note: The note to save.
    /// - Throws: An error if the save operation fails.
    func save(_ note: DataModel.Note) async throws

    /// Deletes a note from storage.
    ///
    /// - Parameter note: The note to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ note: DataModel.Note) async throws
}
