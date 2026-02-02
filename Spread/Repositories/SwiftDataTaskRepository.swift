import Foundation
import SwiftData

/// SwiftData implementation of TaskRepository.
///
/// Provides CRUD operations for tasks using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataTaskRepository: TaskRepository {

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
    /// - Parameter modelContainer: The SwiftData container for persistence.
    init(
        modelContainer: ModelContainer,
        deviceId: UUID = DeviceIdManager.getOrCreateDeviceId(),
        nowProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContainer = modelContainer
        self.deviceId = deviceId
        self.nowProvider = nowProvider
    }

    // MARK: - TaskRepository

    func getTasks() async -> [DataModel.Task] {
        let descriptor = FetchDescriptor<DataModel.Task>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func save(_ task: DataModel.Task) async throws {
        let operation: SyncOperation = hasStoredTask(id: task.id) ? .update : .create
        enqueueTaskMutation(task, operation: operation)
        modelContext.insert(task)
        try modelContext.save()
    }

    func delete(_ task: DataModel.Task) async throws {
        enqueueTaskMutation(task, operation: .delete)
        modelContext.delete(task)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "date", "period", "status"]
    }

    private func enqueueTaskMutation(_ task: DataModel.Task, operation: SyncOperation) {
        let timestamp = nowProvider()
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeTask(
            task,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.task.rawValue,
            entityId: task.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.changedFields
        )
        modelContext.insert(mutation)
    }

    private func hasStoredTask(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<DataModel.Task>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}
