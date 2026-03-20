import Testing
import Foundation
import SwiftData
@testable import Spread

/// Tests for note repository CRUD operations.
///
/// Validates InMemoryNoteRepository, SwiftDataNoteRepository, and
/// MockNoteRepository implementations against the NoteRepository protocol contract.
@Suite("Note Repository Tests")
struct NoteRepositoryTests {

    // MARK: - InMemory CRUD

    /// Conditions: Save a note to an empty InMemory repository.
    /// Expected: getNotes returns one note with the correct title.
    @Test @MainActor func testInMemorySaveAndRetrieve() async throws {
        let repo = InMemoryNoteRepository()
        let note = DataModel.Note(title: "Meeting notes from kickoff")

        try await repo.save(note)
        let result = await repo.getNotes()

        #expect(result.count == 1)
        #expect(result[0].id == note.id)
        #expect(result[0].title == "Meeting notes from kickoff")
    }

    /// Conditions: Save the same note twice.
    /// Expected: Repository contains only one note (no duplicates).
    @Test @MainActor func testInMemorySaveIsIdempotent() async throws {
        let repo = InMemoryNoteRepository()
        let note = DataModel.Note(title: "Test Note")

        try await repo.save(note)
        try await repo.save(note)
        let result = await repo.getNotes()

        #expect(result.count == 1)
    }

    /// Conditions: Save a note, modify its title, save again.
    /// Expected: Repository contains one note with the updated title.
    @Test @MainActor func testInMemoryUpdate() async throws {
        let repo = InMemoryNoteRepository()
        let note = DataModel.Note(title: "Original")

        try await repo.save(note)
        note.title = "Updated"
        try await repo.save(note)

        let result = await repo.getNotes()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated")
    }

    /// Conditions: Save a note, then delete it.
    /// Expected: getNotes returns an empty array.
    @Test @MainActor func testInMemoryDelete() async throws {
        let repo = InMemoryNoteRepository()
        let note = DataModel.Note(title: "To Delete")

        try await repo.save(note)
        try await repo.delete(note)

        let result = await repo.getNotes()
        #expect(result.isEmpty)
    }

    /// Conditions: Delete a note that was never saved.
    /// Expected: Repository remains empty (no error thrown).
    @Test @MainActor func testInMemoryDeleteNonExistentIsNoOp() async throws {
        let repo = InMemoryNoteRepository()
        let note = DataModel.Note(title: "Non-existent")

        try await repo.delete(note)
        let result = await repo.getNotes()

        #expect(result.isEmpty)
    }

    /// Conditions: Create InMemory repository with pre-populated notes.
    /// Expected: getNotes returns the pre-populated notes.
    @Test @MainActor func testInMemoryPrePopulated() async {
        let notes = [
            DataModel.Note(title: "A", createdDate: .now.addingTimeInterval(-100)),
            DataModel.Note(title: "B", createdDate: .now)
        ]
        let repo = InMemoryNoteRepository(notes: notes)

        let result = await repo.getNotes()
        #expect(result.count == 2)
        #expect(result[0].title == "A")
        #expect(result[1].title == "B")
    }

    /// Conditions: Empty InMemory repository.
    /// Expected: getNotes returns an empty array.
    @Test @MainActor func testInMemoryEmptyRepository() async {
        let repo = InMemoryNoteRepository()
        let result = await repo.getNotes()
        #expect(result.isEmpty)
    }

    /// Conditions: Save notes with different createdDates in random order.
    /// Expected: getNotes returns them sorted by createdDate ascending.
    @Test @MainActor func testInMemorySortsByDateAscending() async throws {
        let repo = InMemoryNoteRepository()
        let now = Date.now
        let note1 = DataModel.Note(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let note2 = DataModel.Note(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let note3 = DataModel.Note(title: "Newest", createdDate: now)

        try await repo.save(note3)
        try await repo.save(note1)
        try await repo.save(note2)
        let result = await repo.getNotes()

        #expect(result[0].title == "Oldest")
        #expect(result[1].title == "Middle")
        #expect(result[2].title == "Newest")
    }

    // MARK: - SwiftData CRUD

    /// Conditions: Save a note to an empty SwiftData note repository.
    /// Expected: Fetching notes returns one note with the saved title.
    @Test @MainActor func testSwiftDataSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Test Note", content: "Some content")
        try await repo.save(note)

        let result = await repo.getNotes()
        #expect(result.count == 1)
        #expect(result[0].title == "Test Note")
        #expect(result[0].content == "Some content")
    }

    /// Conditions: Save three notes to the repository.
    /// Expected: Fetching notes returns three notes.
    @Test @MainActor func testSwiftDataSaveMultipleNotes() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataNoteRepository(modelContainer: container)

        let note1 = DataModel.Note(title: "Note 1")
        let note2 = DataModel.Note(title: "Note 2")
        let note3 = DataModel.Note(title: "Note 3")

        try await repo.save(note1)
        try await repo.save(note2)
        try await repo.save(note3)

        let result = await repo.getNotes()
        #expect(result.count == 3)
    }

    /// Conditions: Save a note, then delete it.
    /// Expected: Fetching notes returns an empty list.
    @Test @MainActor func testSwiftDataDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Note to Delete")
        try await repo.save(note)

        var result = await repo.getNotes()
        #expect(result.count == 1)

        try await repo.delete(note)

        result = await repo.getNotes()
        #expect(result.count == 0)
    }

    /// Conditions: Save a note, update its title, and save again.
    /// Expected: Repository has one note with the updated title.
    @Test @MainActor func testSwiftDataUpdate() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Original Title")
        try await repo.save(note)

        note.title = "Updated Title"
        try await repo.save(note)

        let result = await repo.getNotes()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated Title")
    }

    /// Conditions: Save notes with different created dates in non-chronological order.
    /// Expected: Fetching notes returns them sorted by date ascending.
    @Test @MainActor func testSwiftDataSortsByDateAscending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataNoteRepository(modelContainer: container)

        let now = Date.now
        let note1 = DataModel.Note(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let note2 = DataModel.Note(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let note3 = DataModel.Note(title: "Newest", createdDate: now)

        try await repo.save(note3)
        try await repo.save(note1)
        try await repo.save(note2)

        let result = await repo.getNotes()
        #expect(result.count == 3)
        #expect(result[0].title == "Oldest")
        #expect(result[1].title == "Middle")
        #expect(result[2].title == "Newest")
    }

    // MARK: - SwiftData Sync Outbox

    /// Conditions: Save a note with sync enabled.
    /// Expected: An outbox mutation is created with device ID and create operation.
    @Test @MainActor func testSwiftDataSaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repo = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        let note = DataModel.Note(title: "Sync Note")
        try await repo.save(note)

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.note.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save a note, then save again after updating its title.
    /// Expected: An update mutation is enqueued in the outbox.
    @Test @MainActor func testSwiftDataUpdateEnqueuesUpdateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repo = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 200) }
        )

        let note = DataModel.Note(title: "Original")
        try await repo.save(note)

        note.title = "Updated"
        try await repo.save(note)

        let operations = try fetchMutations(from: container).map { $0.operation }

        #expect(operations.contains(SyncOperation.update.rawValue))
    }

    /// Conditions: Save a note, then delete it.
    /// Expected: A delete mutation is enqueued with deleted_at set.
    @Test @MainActor func testSwiftDataDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        var timestamps = [
            Date(timeIntervalSince1970: 300),
            Date(timeIntervalSince1970: 400)
        ]
        let repo = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { timestamps.removeFirst() }
        )

        let note = DataModel.Note(title: "Delete Me")
        try await repo.save(note)
        try await repo.delete(note)

        let mutations = try fetchMutations(from: container)
        let deleteMutation = mutations.last(where: { $0.operation == SyncOperation.delete.rawValue })

        #expect(deleteMutation != nil)

        let record = try decodeRecord(deleteMutation?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 400)))
    }

    // MARK: - Mock Repository

    /// Conditions: Create MockNoteRepository with default sample data.
    /// Expected: Returns non-empty notes with titles.
    @Test @MainActor func testMockRepositoryHasSampleData() async {
        let repo = MockNoteRepository()
        let result = await repo.getNotes()

        #expect(!result.isEmpty)
        #expect(result.allSatisfy { !$0.title.isEmpty })
    }

    /// Conditions: Save a new note into a mock note repository.
    /// Expected: Note count increases by one.
    @Test @MainActor func testMockRepositorySupportsSave() async throws {
        let repo = MockNoteRepository()
        let initialCount = await repo.getNotes().count
        let note = DataModel.Note(title: "New Note")

        try await repo.save(note)
        let result = await repo.getNotes()

        #expect(result.count == initialCount + 1)
    }

    /// Conditions: Delete an existing note from a mock note repository.
    /// Expected: Remaining notes do not include the deleted note.
    @Test @MainActor func testMockRepositorySupportsDelete() async throws {
        let repo = MockNoteRepository()
        let notes = await repo.getNotes()
        guard let noteToDelete = notes.first else {
            Issue.record("No notes to delete")
            return
        }

        try await repo.delete(noteToDelete)
        let remainingNotes = await repo.getNotes()

        #expect(!remainingNotes.contains { $0.id == noteToDelete.id })
    }

    // MARK: - Sync Outbox Helpers

    @MainActor
    private func fetchMutations(from container: ModelContainer) throws -> [DataModel.SyncMutation] {
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    private func decodeRecord(_ data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
