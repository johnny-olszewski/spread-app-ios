import Foundation
import SwiftData

/// SwiftData implementation of `ChangeAwareNoteRepository`.
///
/// Diffs sync-outbox mutations from the caller-supplied `EntityChange` instead of
/// re-fetching pre-mutation state through a throwaway `ModelContext`, as
/// `SwiftDataNoteRepository` does. Create-vs-update is read from `change.isNew`
/// rather than a `fetchCount` query.
///
/// - Note: `ChangeAware` is a temporary qualifier needed only while this type coexists
///   with the legacy `SwiftDataNoteRepository`. Once SPRD-249's cutover deletes that legacy
///   type, rename this to `SwiftDataNoteRepository` (see SPRD-245's renaming plan).
@MainActor
final class SwiftDataChangeAwareNoteRepository: ChangeAwareNoteRepository {

    // MARK: - Properties

    private let modelContainer: ModelContainer
    private let deviceId: UUID
    private let nowProvider: () -> Date

    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    /// Creates a repository with the specified model container.
    ///
    /// - Parameters:
    ///   - modelContainer: The SwiftData container for persistence.
    ///   - deviceId: The device identifier for sync metadata.
    ///   - nowProvider: Closure providing the current time (injectable for testing).
    init(
        modelContainer: ModelContainer,
        deviceId: UUID = DeviceIdManager.getOrCreateDeviceId(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.deviceId = deviceId
        self.nowProvider = nowProvider
    }

    // MARK: - ChangeAwareNoteRepository

    /// Fetches all notes from the store, ordered by creation date.
    func getNotes() async -> [DataModel.Note] {
        let descriptor = FetchDescriptor<DataModel.Note>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    /// Persists `note` and enqueues sync-outbox mutations for the note, its assignments, and
    /// its tags, diffing against `change` rather than re-fetching pre-mutation state from disk.
    func save(_ note: DataModel.Note, change: EntityChange<NoteAssignment>) async throws {
        try await saveAll([NoteSaveRequest(note: note, change: change)])
    }

    /// Persists every note in `requests` and enqueues their sync-outbox mutations in a single
    /// persistence commit, regardless of how many requests are supplied.
    func saveAll(_ requests: [NoteSaveRequest]) async throws {
        let timestamp = nowProvider()

        for request in requests {
            let operation: SyncOperation = request.change.isNew ? .create : .update

            enqueueNoteMutation(request.note, operation: operation, timestamp: timestamp)
            enqueueNoteAssignmentMutations(
                noteId: request.note.id,
                previousAssignments: request.change.previousAssignments,
                currentAssignments: request.note.assignments,
                timestamp: timestamp
            )
            enqueueNoteTagMutations(
                noteId: request.note.id,
                previousTagIds: request.change.previousTagIDs,
                currentTagIds: request.note.tags.map(\.id),
                timestamp: timestamp
            )
            modelContext.insert(request.note)
        }

        try modelContext.save()
    }

    /// Deletes `note` and enqueues tombstone mutations for the note, its assignments, and tags.
    func delete(_ note: DataModel.Note) async throws {
        let timestamp = nowProvider()

        enqueueNoteMutation(note, operation: .delete, timestamp: timestamp)
        enqueueNoteAssignmentTombstones(note.assignments, noteId: note.id, timestamp: timestamp)
        enqueueNoteTagTombstones(tagIds: note.tags.map(\.id), noteId: note.id, timestamp: timestamp)
        modelContext.delete(note)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        /// Fields reported as changed on every non-delete note mutation.
        static let changedFields = ["title", "content", "date", "period", "status", "list_id"]
        /// Fields reported as changed on every non-delete note-assignment mutation.
        static let assignmentChangedFields = ["period", "date", "status"]
    }

    /// Serializes `note` and enqueues a single sync-outbox mutation for it.
    private func enqueueNoteMutation(
        _ note: DataModel.Note,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        // TODO: SPRD-250 - replace serializeNote and the hardcoded entityType below with a
        // `SerializableData` conformance on `DataModel.Note`.
        guard let recordData = SyncSerializer.serializeNote(
            note,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.note.rawValue,
            entityId: note.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    /// Diffs `previousAssignments` against `currentAssignments` by ID, enqueueing a create
    /// mutation for additions, an update mutation for changed assignments, and a tombstone for
    /// any previous assignment no longer present in `currentAssignments`.
    private func enqueueNoteAssignmentMutations(
        noteId: UUID,
        previousAssignments: [NoteAssignment],
        currentAssignments: [NoteAssignment],
        timestamp: Date
    ) {
        var previousByID = Dictionary(uniqueKeysWithValues: previousAssignments.map { ($0.id, $0) })

        for assignment in currentAssignments {
            let operation: SyncOperation

            if let previous = previousByID.removeValue(forKey: assignment.id) {
                guard previous != assignment else { continue }
                operation = .update
            } else {
                operation = .create
            }

            enqueueNoteAssignmentMutation(
                assignment,
                noteId: noteId,
                operation: operation,
                timestamp: timestamp
            )
        }

        enqueueNoteAssignmentTombstones(
            Array(previousByID.values),
            noteId: noteId,
            timestamp: timestamp
        )
    }

    /// Enqueues a delete mutation for each of `assignments`.
    private func enqueueNoteAssignmentTombstones(
        _ assignments: [NoteAssignment],
        noteId: UUID,
        timestamp: Date
    ) {
        for assignment in assignments {
            enqueueNoteAssignmentMutation(
                assignment,
                noteId: noteId,
                operation: .delete,
                timestamp: timestamp
            )
        }
    }

    /// Serializes `assignment` and enqueues a single sync-outbox mutation for it.
    private func enqueueNoteAssignmentMutation(
        _ assignment: NoteAssignment,
        noteId: UUID,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeNoteAssignment(
            assignment,
            noteId: noteId,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.noteAssignment.rawValue,
            entityId: assignment.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.assignmentChangedFields
        )
        modelContext.insert(mutation)
    }

    /// Diffs `previousTagIds` against `currentTagIds`, enqueueing a create mutation for each
    /// newly-added tag and a tombstone for each removed tag.
    private func enqueueNoteTagMutations(
        noteId: UUID,
        previousTagIds: [UUID],
        currentTagIds: [UUID],
        timestamp: Date
    ) {
        let previousSet = Set(previousTagIds)
        let currentSet = Set(currentTagIds)

        for tagId in currentSet.subtracting(previousSet) {
            guard let recordData = SyncSerializer.serializeNoteTag(
                noteId: noteId, tagId: tagId, timestamp: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.noteTag.rawValue,
                entityId: UUID(),
                operation: SyncOperation.create.rawValue,
                recordData: recordData
            )
            modelContext.insert(mutation)
        }

        enqueueNoteTagTombstones(
            tagIds: Array(previousSet.subtracting(currentSet)),
            noteId: noteId,
            timestamp: timestamp
        )
    }

    /// Enqueues a delete mutation for each tag ID in `tagIds`.
    private func enqueueNoteTagTombstones(tagIds: [UUID], noteId: UUID, timestamp: Date) {
        for tagId in tagIds {
            guard let recordData = SyncSerializer.serializeNoteTag(
                noteId: noteId, tagId: tagId, timestamp: timestamp, deletedAt: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.noteTag.rawValue,
                entityId: UUID(),
                operation: SyncOperation.delete.rawValue,
                recordData: recordData
            )
            modelContext.insert(mutation)
        }
    }
}
