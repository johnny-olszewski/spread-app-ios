import Foundation
import SwiftData

/// SwiftData implementation of NoteRepository.
///
/// Provides CRUD operations for notes using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataNoteRepository: NoteRepository {

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

    // MARK: - NoteRepository

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

    func save(_ note: DataModel.Note) async throws {
        let operation: SyncOperation = hasStoredNote(id: note.id) ? .update : .create
        let timestamp = nowProvider()
        let previousAssignments = storedNoteAssignments(id: note.id) ?? []
        let previousTagIds = storedNoteTagIds(id: note.id) ?? []

        enqueueNoteMutation(note, operation: operation, timestamp: timestamp)
        enqueueNoteAssignmentMutations(
            noteId: note.id,
            previousAssignments: previousAssignments,
            currentAssignments: note.assignments,
            timestamp: timestamp
        )
        enqueueNoteTagMutations(
            noteId: note.id,
            previousTagIds: previousTagIds,
            currentTagIds: note.tags.map(\.id),
            timestamp: timestamp
        )
        modelContext.insert(note)
        try modelContext.save()
    }

    func delete(_ note: DataModel.Note) async throws {
        let timestamp = nowProvider()
        let previousAssignments = storedNoteAssignments(id: note.id) ?? note.assignments
        let previousTagIds = storedNoteTagIds(id: note.id) ?? note.tags.map(\.id)

        enqueueNoteMutation(note, operation: .delete, timestamp: timestamp)
        enqueueNoteAssignmentTombstones(
            previousAssignments,
            noteId: note.id,
            timestamp: timestamp
        )
        enqueueNoteTagTombstones(
            tagIds: previousTagIds,
            noteId: note.id,
            timestamp: timestamp
        )
        modelContext.delete(note)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "content", "date", "period", "status", "list_id"]
        static let assignmentChangedFields = ["period", "date", "status"]
    }

    private func enqueueNoteMutation(
        _ note: DataModel.Note,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeNoteEntry(
            note,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.entry.rawValue,
            entityId: note.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func enqueueNoteAssignmentMutations(
        noteId: UUID,
        previousAssignments: [Assignment],
        currentAssignments: [Assignment],
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

    private func enqueueNoteAssignmentTombstones(
        _ assignments: [Assignment],
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

    private func enqueueNoteAssignmentMutation(
        _ assignment: Assignment,
        noteId: UUID,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeAssignment(
            assignment,
            entryId: noteId,
            entryType: .note,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.assignment.rawValue,
            entityId: assignment.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.assignmentChangedFields
        )
        modelContext.insert(mutation)
    }

    private func enqueueNoteTagMutations(
        noteId: UUID,
        previousTagIds: [UUID],
        currentTagIds: [UUID],
        timestamp: Date
    ) {
        let previousSet = Set(previousTagIds)
        let currentSet = Set(currentTagIds)

        for tagId in currentSet.subtracting(previousSet) {
            guard let recordData = SyncSerializer.serializeEntryTag(
                entryId: noteId, tagId: tagId, timestamp: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.entryTag.rawValue,
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

    private func enqueueNoteTagTombstones(tagIds: [UUID], noteId: UUID, timestamp: Date) {
        for tagId in tagIds {
            guard let recordData = SyncSerializer.serializeEntryTag(
                entryId: noteId, tagId: tagId, timestamp: timestamp, deletedAt: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.entryTag.rawValue,
                entityId: UUID(),
                operation: SyncOperation.delete.rawValue,
                recordData: recordData
            )
            modelContext.insert(mutation)
        }
    }

    private func hasStoredNote(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func storedNoteAssignments(id: UUID) -> [Assignment]? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.assignments
    }

    private func storedNoteTagIds(id: UUID) -> [UUID]? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.tags.map(\.id)
    }
}
