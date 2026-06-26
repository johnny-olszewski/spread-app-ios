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
        let repository = SwiftDataChangeAwareNoteRepository(
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
        let repository = SwiftDataChangeAwareNoteRepository(
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
        let repository = SwiftDataChangeAwareNoteRepository(
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

    // MARK: - Parity with SwiftDataNoteRepository

    /// Conditions: Run the same create-then-update-then-delete sequence through both
    /// `SwiftDataNoteRepository` (legacy disk re-fetch diffing, no outbox coalescing) and
    /// `SwiftDataChangeAwareNoteRepository` (caller-supplied descriptor diffing, with SPRD-253's
    /// outbox coalescing), using separate in-memory containers.
    /// Expected: **Intentional divergence** — the legacy repository still produces one row per
    /// mutation (5 rows: note create/update/delete + assignment create/delete), while the
    /// change-aware repository coalesces the note's update into its still-unsent create row and
    /// the assignment's delete into its still-unsent create row, producing exactly 2 rows (note
    /// create, assignment create) before the final deletes coalesce those into 2 delete rows.
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

        let assignment = Assignment(period: .day, date: Date(timeIntervalSince1970: 5_000), status: .active)
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

        // Legacy: one row per mutation — create/create, then update (no assignment change), then
        // delete/delete. No coalescing.
        #expect(legacySequence.map(\.0) == [
            SyncEntityType.entry.rawValue, SyncEntityType.assignment.rawValue,
            SyncEntityType.entry.rawValue,
            SyncEntityType.entry.rawValue, SyncEntityType.assignment.rawValue
        ])
        #expect(legacySequence.map(\.1) == [
            SyncOperation.create.rawValue, SyncOperation.create.rawValue,
            SyncOperation.update.rawValue,
            SyncOperation.delete.rawValue, SyncOperation.delete.rawValue
        ])

        // Change-aware: the update coalesces into the still-unsent note create row (stays
        // create), then the final delete coalesces both rows down to delete — 2 rows total
        // instead of 5.
        #expect(changeAwareSequence.map(\.0) == [SyncEntityType.entry.rawValue, SyncEntityType.assignment.rawValue])
        #expect(changeAwareSequence.map(\.1) == [SyncOperation.delete.rawValue, SyncOperation.delete.rawValue])
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
