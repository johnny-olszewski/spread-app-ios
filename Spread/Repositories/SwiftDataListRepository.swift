import Foundation
import SwiftData

/// SwiftData implementation of ListRepository.
///
/// Provides CRUD operations for lists using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataListRepository: ListRepository {

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

    // MARK: - ListRepository

    func getLists() async -> [DataModel.List] {
        let descriptor = FetchDescriptor<DataModel.List>(
            predicate: #Predicate { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func save(_ list: DataModel.List) async throws {
        let operation: SyncOperation = hasStoredList(id: list.id) ? .update : .create
        let timestamp = nowProvider()
        enqueueListMutation(list, operation: operation, timestamp: timestamp)
        modelContext.insert(list)
        try modelContext.save()
    }

    func delete(_ list: DataModel.List) async throws {
        let timestamp = nowProvider()
        enqueueListMutation(list, operation: .delete, timestamp: timestamp)
        modelContext.delete(list)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["name"]
    }

    private func enqueueListMutation(
        _ list: DataModel.List,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeList(
            list,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else { return }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.list.rawValue,
            entityId: list.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredList(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.List>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
