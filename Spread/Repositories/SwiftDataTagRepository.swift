import Foundation
import SwiftData

/// SwiftData implementation of TagRepository.
///
/// Provides CRUD operations for tags using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataTagRepository: TagRepository {

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

    // MARK: - TagRepository

    func getTags() async -> [DataModel.Tag] {
        let descriptor = FetchDescriptor<DataModel.Tag>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(_ tag: DataModel.Tag) async throws {
        let operation: SyncOperation = hasStoredTag(id: tag.id) ? .update : .create
        let timestamp = nowProvider()
        enqueueTagMutation(tag, operation: operation, timestamp: timestamp)
        modelContext.insert(tag)
        try modelContext.save()
    }

    func delete(_ tag: DataModel.Tag) async throws {
        let timestamp = nowProvider()
        enqueueTagMutation(tag, operation: .delete, timestamp: timestamp)
        modelContext.delete(tag)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["name"]
    }

    private func enqueueTagMutation(
        _ tag: DataModel.Tag,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeTag(
            tag,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else { return }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.tag.rawValue,
            entityId: tag.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredTag(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Tag>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
