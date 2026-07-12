import Foundation

/// Error-injecting note repository for unit tests.
///
/// Stores notes in memory like `TestNoteRepository`, but throws `saveError`
/// from `save`/`saveAll` when set — enabling failure-path assertions
/// (e.g. that a failed edit-save surfaces an error to the user).
@MainActor
final class MockNoteRepository: NoteRepository {

    // MARK: - Properties

    /// Error thrown by `save`/`saveAll` when non-nil.
    var saveError: Error?

    private var notes: [UUID: DataModel.Note]

    // MARK: - Initialization

    /// Creates an empty repository.
    init() {
        self.notes = [:]
    }

    // MARK: - NoteRepository

    func getNotes() async -> [DataModel.Note] {
        Array(notes.values).sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ note: DataModel.Note, change: EntityChange) async throws {
        if let saveError { throw saveError }
        notes[note.id] = note
    }

    func saveAll(_ requests: [NoteSaveRequest]) async throws {
        if let saveError { throw saveError }
        for request in requests {
            notes[request.note.id] = request.note
        }
    }

    func delete(_ note: DataModel.Note) async throws {
        notes.removeValue(forKey: note.id)
    }
}
