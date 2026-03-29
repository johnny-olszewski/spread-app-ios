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

        enqueueNoteMutation(note, operation: operation, timestamp: timestamp)
        enqueueNoteAssignmentMutations(
            noteId: note.id,
            previousAssignments: previousAssignments,
            currentAssignments: note.assignments,
            timestamp: timestamp
        )
        modelContext.insert(note)
        try modelContext.save()
    }

    func delete(_ note: DataModel.Note) async throws {
        let timestamp = nowProvider()
        let previousAssignments = storedNoteAssignments(id: note.id) ?? note.assignments

        enqueueNoteMutation(note, operation: .delete, timestamp: timestamp)
        enqueueNoteAssignmentTombstones(
            previousAssignments,
            noteId: note.id,
            timestamp: timestamp
        )
        modelContext.delete(note)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "content", "date", "period", "status"]
        static let assignmentChangedFields = ["period", "date", "status"]
    }

    private func enqueueNoteMutation(
        _ note: DataModel.Note,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
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

    private func hasStoredNote(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func storedNoteAssignments(id: UUID) -> [NoteAssignment]? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.assignments
    }
}
