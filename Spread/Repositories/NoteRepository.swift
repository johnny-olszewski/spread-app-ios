import Foundation

/// Protocol defining change-aware persistence operations for notes.
///
/// `save` takes an explicit `EntityChange` describing the note's pre-mutation
/// assignments/tags so the repository can diff for the sync outbox without re-fetching
/// prior state from disk.
@MainActor
protocol NoteRepository: Sendable {
    /// Retrieves all notes from storage.
    func getNotes() async -> [DataModel.Note]

    /// Saves a note, diffing the sync outbox against the caller-supplied pre-mutation state.
    ///
    /// - Parameters:
    ///   - note: The note to save, already mutated to its new state.
    ///   - change: The note's identity/assignments/tags as they existed before mutation.
    /// - Throws: An error if the save operation fails.
    func save(_ note: DataModel.Note, change: EntityChange) async throws

    /// Saves multiple notes in a single persistence commit, each diffed against its own
    /// caller-supplied pre-mutation state.
    ///
    /// - Parameter requests: The notes to save, paired with their pre-mutation change descriptors.
    /// - Throws: An error if the save operation fails.
    func saveAll(_ requests: [NoteSaveRequest]) async throws

    /// Deletes a note from storage.
    ///
    /// - Parameter note: The note to delete.
    /// - Throws: An error if the delete operation fails.
    func delete(_ note: DataModel.Note) async throws
}
