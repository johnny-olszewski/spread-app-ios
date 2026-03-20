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
        enqueueNoteMutation(note, operation: operation)
        modelContext.insert(note)
        try modelContext.save()
    }

    func delete(_ note: DataModel.Note) async throws {
        enqueueNoteMutation(note, operation: .delete)
        modelContext.delete(note)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "content", "date", "period", "status"]
    }

    private func enqueueNoteMutation(_ note: DataModel.Note, operation: SyncOperation) {
        let timestamp = nowProvider()
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

    private func hasStoredNote(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Note>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
