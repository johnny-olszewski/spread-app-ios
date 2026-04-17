import Foundation
import SwiftData

/// SwiftData implementation of CollectionRepository.
///
/// Provides CRUD operations for collections using SwiftData persistence.
/// Collections are sorted by modifiedDate descending (newest first).
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataCollectionRepository: CollectionRepository {

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

    // MARK: - CollectionRepository

    func getCollections() async -> [DataModel.Collection] {
        let descriptor = FetchDescriptor<DataModel.Collection>(
            sortBy: [SortDescriptor(\.modifiedDate, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func save(_ collection: DataModel.Collection) async throws {
        let operation: SyncOperation = hasStoredCollection(id: collection.id) ? .update : .create
        enqueueCollectionMutation(collection, operation: operation)
        modelContext.insert(collection)
        try modelContext.save()
    }

    func delete(_ collection: DataModel.Collection) async throws {
        enqueueCollectionMutation(collection, operation: .delete)
        modelContext.delete(collection)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "content"]
    }

    private func enqueueCollectionMutation(_ collection: DataModel.Collection, operation: SyncOperation) {
        let timestamp = nowProvider()
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeCollection(
            collection,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.collection.rawValue,
            entityId: collection.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredCollection(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Collection>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
