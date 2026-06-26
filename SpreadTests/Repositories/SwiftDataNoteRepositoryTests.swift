import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataNoteRepository`, the canonical note repository
/// implementation. Covers CRUD and sync-outbox behavior, including reading pre-mutation
/// assignments/tags from a caller-supplied `EntityChange` instead of re-fetching from disk.
@MainActor
struct SwiftDataNoteRepositoryTests {

    // MARK: - CRUD

    /// Conditions: Save a note to an empty repository with a default (new) change descriptor.
    /// Expected: Fetching notes returns one note with the saved title.
    @Test func testSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(modelContainer: container)

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
        let repository = SwiftDataNoteRepository(modelContainer: container)

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
        let repository = SwiftDataNoteRepository(modelContainer: container)

        let note = DataModel.Note(title: "Note to Delete")
        try await repository.save(note, change: EntityChange())

        try await repository.delete(note)

        let notes = await repository.getNotes()
        #expect(notes.isEmpty)
    }

    /// Conditions: Save notes with different created dates in non-chronological order.
    /// Expected: Fetching notes returns them sorted by date ascending.
    @Test func testSaveReturnsNotesSortedByDateAscending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(modelContainer: container)

        let now = Date.now
        let note1 = DataModel.Note(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let note2 = DataModel.Note(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let note3 = DataModel.Note(title: "Newest", createdDate: now)

        try await repository.save(note3, change: EntityChange())
        try await repository.save(note1, change: EntityChange())
        try await repository.save(note2, change: EntityChange())

        let notes = await repository.getNotes()
        #expect(notes.count == 3)
        #expect(notes[0].title == "Oldest")
        #expect(notes[1].title == "Middle")
        #expect(notes[2].title == "Newest")
    }

    /// Conditions: Save a note, mutate its title, then save again with `isNew: false`.
    /// Expected: Repository has one note with the updated title (no duplicate row created).
    @Test func testUpdateExistingNote() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(modelContainer: container)

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
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 100) }
        )

        let note = DataModel.Note(title: "Sync Note")
        try await repository.save(note, change: EntityChange())

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.entry.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save a note with `change.isNew == false`, simulating an update to a
    /// previously-persisted entity the caller already had in memory.
    /// Expected: An update mutation is enqueued, not a create mutation.
    @Test func testSaveEnqueuesUpdateMutationFromIsNewFlag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(
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
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 110) }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 1_000), status: .active)
        let note = DataModel.Note(title: "Assigned note", assignments: [assignment])

        try await repository.save(note, change: EntityChange())

        let mutations = try fetchMutations(from: container)
        #expect(mutations.map(\.entityType) == [
            SyncEntityType.entry.rawValue,
            SyncEntityType.assignment.rawValue
        ])

        let assignmentMutation = mutations.last
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)
    }

    /// Conditions: Save a note with an assignment, mutate the assignment's status in place,
    /// then save again passing the pre-mutation assignment via `change.previousAssignments`
    /// (as a real caller would, captured one statement before mutating).
    /// Expected: Per SPRD-253's outbox coalescing policy, the second save's update coalesces
    /// into the still-unsent create row for the same assignment rather than appending a second
    /// row — the row's operation stays `create` (an unsent create is never downgraded), but its
    /// record data reflects the latest status.
    @Test func testSaveEnqueuesAssignmentUpdateMutationFromSuppliedPreviousState() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { Date(timeIntervalSince1970: 210) }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 2_000), status: .active)
        let note = DataModel.Note(title: "Assigned note", assignments: [assignment])
        try await repository.save(note, change: EntityChange())

        let previousAssignments = note.assignments
        note.assignments[0].status = .complete
        try await repository.save(note, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentMutations = mutations.filter { $0.entityType == SyncEntityType.assignment.rawValue }
        #expect(assignmentMutations.count == 1)

        let assignmentMutation = assignmentMutations.first
        #expect(assignmentMutation?.entityId == assignment.id)
        #expect(assignmentMutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(assignmentMutation?.recordData)
        #expect(record?["status"] as? String == EntryStatus.complete.rawValue)
    }

    /// Conditions: Save a note with an assignment, clear its assignments, then save again
    /// passing the pre-mutation assignment via `change.previousAssignments`.
    /// Expected: A note-assignment tombstone is enqueued even though the parent note remains.
    @Test func testSaveEnqueuesAssignmentDeleteWhenAssignmentRemoved() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [Date(timeIntervalSince1970: 700), Date(timeIntervalSince1970: 800)]
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 4_000), status: .active)
        let note = DataModel.Note(title: "Inbox fallback", assignments: [assignment])
        try await repository.save(note, change: EntityChange())

        let previousAssignments = note.assignments
        note.assignments.removeAll()
        try await repository.save(note, change: EntityChange(isNew: false, previousAssignments: previousAssignments))

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.assignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)

        let record = try decodeRecord(assignmentDelete?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 800)))
    }

    /// Conditions: Save a note with an assignment, then delete the note.
    /// Expected: A note-assignment delete mutation is enqueued as a tombstone, derived from
    /// `note.assignments` directly (delete needs no caller-supplied change descriptor).
    @Test func testDeleteEnqueuesAssignmentDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        var timestamps = [Date(timeIntervalSince1970: 500), Date(timeIntervalSince1970: 600)]
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            deviceId: UUID(),
            nowProvider: { timestamps.removeFirst() }
        )

        let assignment = Assignment(period: .month, date: Date(timeIntervalSince1970: 3_000), status: .active)
        let note = DataModel.Note(title: "Delete assigned note", assignments: [assignment])
        try await repository.save(note, change: EntityChange())
        try await repository.delete(note)

        let mutations = try fetchMutations(from: container)
        let assignmentDelete = mutations.last {
            $0.entityType == SyncEntityType.assignment.rawValue &&
            $0.operation == SyncOperation.delete.rawValue
        }

        #expect(assignmentDelete != nil)
        #expect(assignmentDelete?.entityId == assignment.id)
    }

    // MARK: - Batched Saves

    /// Conditions: Save three new notes in a single `saveAll` call.
    /// Expected: All three notes are persisted, and the outbox contains exactly one create
    /// mutation per note, in request order — the entire batch is committed as one unit, not
    /// as three independent `save` calls.
    @Test func testSaveAllPersistsAllNotesInOneCommit() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            nowProvider: { Date(timeIntervalSince1970: 300) }
        )

        let notes = [
            DataModel.Note(title: "Batch Note 1"),
            DataModel.Note(title: "Batch Note 2"),
            DataModel.Note(title: "Batch Note 3")
        ]
        try await repository.saveAll(notes.map { NoteSaveRequest(note: $0) })

        let savedNotes = await repository.getNotes()
        #expect(savedNotes.count == 3)

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 3)
        #expect(mutations.allSatisfy { $0.operation == SyncOperation.create.rawValue })
        #expect(mutations.map(\.entityId) == notes.map(\.id))
    }

    /// Conditions: Save one new note and one existing note (via `isNew: false`) in the same
    /// `saveAll` call.
    /// Expected: The outbox contains a create mutation for the new note and an update mutation
    /// for the existing note, proving each request is diffed independently within the batch.
    @Test func testSaveAllDiffsEachRequestIndependently() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataNoteRepository(
            modelContainer: container,
            nowProvider: { Date(timeIntervalSince1970: 310) }
        )

        let newNote = DataModel.Note(title: "New Note")
        let existingNote = DataModel.Note(title: "Existing Note")
        try await repository.saveAll([
            NoteSaveRequest(note: newNote),
            NoteSaveRequest(note: existingNote, change: EntityChange(isNew: false))
        ])

        let mutations = try fetchMutations(from: container)
        #expect(mutations.first { $0.entityId == newNote.id }?.operation == SyncOperation.create.rawValue)
        #expect(mutations.first { $0.entityId == existingNote.id }?.operation == SyncOperation.update.rawValue)
    }

    // MARK: - Outbox Coalescing Across a Full Mutation Sequence

    /// Conditions: Create a note with an assignment, update the note's title (assignment
    /// unchanged), then delete the note — three saves/deletes in sequence, each while the
    /// prior mutation's row is still unsent.
    /// Expected: Per SPRD-253's outbox coalescing, this produces exactly 2 final rows (note,
    /// assignment) instead of one row per mutation — the update coalesces into the still-unsent
    /// create row (stays `create`), then the final delete coalesces both down to `delete`.
    @Test func testFullMutationSequenceCoalescesToFinalRowsOnly() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let nowProvider = { Date(timeIntervalSince1970: 1_000) }

        let repository = SwiftDataNoteRepository(
            modelContainer: container, deviceId: deviceId, nowProvider: nowProvider
        )

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 5_000), status: .active)
        let note = DataModel.Note(title: "Sequence Note", assignments: [assignment])

        try await repository.save(note, change: EntityChange())

        let previousAssignments = note.assignments
        note.title = "Updated Sequence Note"
        try await repository.save(
            note,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments)
        )

        try await repository.delete(note)

        let sequence = try fetchMutations(from: container).map { ($0.entityType, $0.operation) }

        #expect(sequence.map(\.0) == [SyncEntityType.entry.rawValue, SyncEntityType.assignment.rawValue])
        #expect(sequence.map(\.1) == [SyncOperation.delete.rawValue, SyncOperation.delete.rawValue])
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
