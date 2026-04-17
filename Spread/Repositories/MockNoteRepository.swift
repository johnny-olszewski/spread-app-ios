import Foundation

/// Mock note repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockNoteRepository: NoteRepository {

    // MARK: - Properties

    private var notes: [UUID: DataModel.Note]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample notes.
    init() {
        let sampleNotes = TestData.sampleNotes()
        self.notes = Dictionary(uniqueKeysWithValues: sampleNotes.map { ($0.id, $0) })
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
