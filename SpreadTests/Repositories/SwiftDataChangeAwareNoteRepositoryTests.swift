import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataChangeAwareNoteRepository`.
///
/// Mirrors the `SwiftDataNoteRepository` cases in `NoteRepositoryTests` to prove the
/// change-aware save path produces identical CRUD and sync-outbox behavior while reading
/// pre-mutation assignments/tags from a caller-supplied `EntityChange` instead of re-fetching
/// from disk.
@MainActor
struct SwiftDataChangeAwareNoteRepositoryTests {

    // MARK: - CRUD

    /// Conditions: Save a note to an empty repository with a default (new) change descriptor.
    /// Expected: Fetching notes returns one note with the saved title.
    @Test func testSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Test Note")
        try await repository.save(note, change: EntityChange())

        let notes = await repository.getNotes()
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Test Note")
    }

    /// Conditions: Save three notes, each as a new entity.
    /// Expected: Fetching notes returns three notes.
    @Test func testSaveMultipleNotes() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(modelContainer: container)

        try await repository.save(DataModel.Note(title: "Note 1"), change: EntityChange())
        try await repository.save(DataModel.Note(title: "Note 2"), change: EntityChange())
        try await repository.save(DataModel.Note(title: "Note 3"), change: EntityChange())

        let notes = await repository.getNotes()
        #expect(notes.count == 3)
    }

    /// Conditions: Save a note, then delete it.
    /// Expected: Fetching notes returns an empty list.
    @Test func testDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Note to Delete")
        try await repository.save(note, change: EntityChange())

        try await repository.delete(note)

        let notes = await repository.getNotes()
        #expect(notes.isEmpty)
    }

    /// Conditions: Save a note, mutate its title, then save again with `isNew: false`.
    /// Expected: Repository has one note with the updated title (no duplicate row created).
    @Test func testUpdateExistingNote() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Original Title")
        try await repository.save(note, change: EntityChange())

        note.title = "Updated Title"
        try await repository.save(note, change: EntityChange(isNew: false))

        let notes = await repository.getNotes()
        #expect(notes.count == 1)
        #expect(notes.first?.title == "Updated Title")
    }

    // MARK: - Sync Outbox: Parent Entity

    /// Conditions: Save a new note with `change.isNew == true`.
    /// Expected: An outbox mutation is enqueued with a create operation, with no disk re-fetch.
    @Test func testSaveEnqueuesCreateMutationFromIsNewFlag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataChangeAwareNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        let note = DataModel.Note(title: "Sync Note")
        try await repository.save(note, change: EntityChange())

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.note.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save a note with `change.isNew == false`, simulating an update to a
    /// previously-persisted entity the caller already had in memory.
    /// Expected: An update mutation is enqueued, not a create mutation.
    @Test func testSaveEnqueuesUpdateMutationFromIsNewFlag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 200) }
        )

        let note = DataModel.Note(title: "Existing Note")
        try await repository.save(note, change: EntityChange(isNew: false))

        let mutation = try fetchMutations(from: container).first
        #expect(mutation?.operation == SyncOperation.update.rawValue)
    }

    // MARK: - Sync Outbox: Assignments

    /// Conditions: Save a note with an initial spread assignment as a new entity.
    /// Expected: Parent note mutation is enqueued before a child note-assignment create mutation.
    @Test func testSaveEnqueuesAssignmentCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataChangeAwareNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 110) }
        )

        let assignment = NoteAssignment(period: .day, date: Date(timeIntervalSince1970: 1_000), status: .active)
        let note = DataModel.Note(title: "Assigned note", assignments: [assignment])

        try await repository.save(note, change: EntityChange())

        let mutations = try fetchMutations(from: container)
        #expect(mutations.map(\.entityType) == [
            SyncEntityType.note.rawValue,
            SyncEntityType.noteAssignment.rawValue
        ])

        let assignmentMutation = mutations.last
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)
    }

    /// Conditions: Save a note with an assignment, mutate the assignment's status in place,
    /// then save again passing the pre-mutation assignment via `change.previousAssignments`
    /// (as a real caller would, captured one statement before mutating).
    /// Expected: An assignment update mutation is enqueued for the same logical assignment,
    /// proving the diff is computed from the supplied descriptor rather than a disk re-fetch.
    @Test func testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataChangeAwareNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 210) }
        )

        let assignment = NoteAssignment(period: .day, date: Date(timeIntervalSince1970: 2_000), status: .active)
        let note = DataModel.Note(title: "Assigned note", assignments: [assignment])
        try await repository.save(note, change: EntityChange())

        let previousAssignments = note.assignments
        note.assignments[0].status = .complete
        try await repository.save(note, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentUpdate = mutations.last {
            $0.entityType == SyncEntityType.noteAssignment.rawValue &&
            $0.operation == SyncOperation.update.rawValue
        }

        #expect(assignmentUpdate != nil)
        #expect(assignmentUpdate?.entityId == assignment.id)

        let record = try decodeRecord(assignmentUpdate?.recordData)
        #expect(record?["status"] as? String == EntryStatus.complete.rawValue)
    }

    /// Conditions: Save a note with an assignment, then delete the note.
    /// Expected: A note-assignment delete mutation is enqueued as a tombstone, derived from
    /// `note.assignments` directly (delete needs no caller-supplied change descriptor).
    @Test func testDeleteEnqueuesAssignmentDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [Date(timeIntervalSince1970: 500), Date(timeIntervalSince1970: 600)]
        let repository = SwiftDataChangeAwareNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = NoteAssignment(period: .month, date: Date(timeIntervalSince1970: 3_000), status: .active)
        let note = DataModel.Note(title: "Delete assigned note", assignments: [assignment])
        try await repository.save(note, change: EntityChange())
        try await repository.delete(note)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.noteAssignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)
    }

    // MARK: - Parity with SwiftDataNoteRepository

    /// Conditions: Run the same create-then-update-then-delete sequence through both
    /// `SwiftDataNoteRepository` (legacy disk re-fetch diffing) and
    /// `SwiftDataChangeAwareNoteRepository` (caller-supplied descriptor diffing), using
    /// separate in-memory containers.
    /// Expected: Both produce the same sequence of outbox entity types and operations.
    @Test func testProducesSameOutboxSequenceAsLegacyRepository() async throws {
        let legacyContainer = try ModelContainerFactory.makeInMemory()
        let changeAwareContainer = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let nowProvider = { Date(timeIntervalSince1970: 1_000) }

        let legacyRepository = SwiftDataNoteRepository(
            modelContainer: legacyContainer, deviceId: deviceId, nowProvider: nowProvider
        )
        let changeAwareRepository = SwiftDataChangeAwareNoteRepository(
            modelContainer: changeAwareContainer, deviceId: deviceId, nowProvider: nowProvider
        )

        let assignment = NoteAssignment(period: .day, date: Date(timeIntervalSince1970: 5_000), status: .active)
        let legacyNote = DataModel.Note(title: "Parity Note", assignments: [assignment])
        let changeAwareNote = DataModel.Note(
            id: legacyNote.id, title: "Parity Note", assignments: [assignment]
        )

        try await legacyRepository.save(legacyNote)
        try await changeAwareRepository.save(changeAwareNote, change: EntityChange())

        legacyNote.title = "Updated Parity Note"
        let previousAssignments = changeAwareNote.assignments
        changeAwareNote.title = "Updated Parity Note"
        try await legacyRepository.save(legacyNote)
        try await changeAwareRepository.save(
            changeAwareNote,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments)
        )

        try await legacyRepository.delete(legacyNote)
        try await changeAwareRepository.delete(changeAwareNote)

        let legacySequence = try fetchMutations(from: legacyContainer).map { ($0.entityType, $0.operation) }
        let changeAwareSequence = try fetchMutations(from: changeAwareContainer).map { ($0.entityType, $0.operation) }

        #expect(legacySequence.map(\.0) == changeAwareSequence.map(\.0))
        #expect(legacySequence.map(\.1) == changeAwareSequence.map(\.1))
    }

    // MARK: - Sync Outbox Helpers

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
