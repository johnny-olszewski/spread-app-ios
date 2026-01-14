import struct Foundation.UUID

/// In-memory note repository for unit testing.
///
/// Provides a working repository implementation that stores notes in memory.
/// Supports initialization with existing notes for test setup.
@MainActor
final class InMemoryNoteRepository: NoteRepository {

    // MARK: - Properties

    private var notes: [UUID: DataModel.Note]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.notes = [:]
    }

    /// Creates a repository pre-populated with notes.
    ///
    /// - Parameter notes: Initial notes to populate the repository.
    init(notes: [DataModel.Note]) {
        self.notes = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
    }

    // MARK: - NoteRepository

    func getNotes() async -> [DataModel.Note] {
        Array(notes.values).sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ note: DataModel.Note) async throws {
        notes[note.id] = note
    }

    func delete(_ note: DataModel.Note) async throws {
        notes.removeValue(forKey: note.id)
    }
}
