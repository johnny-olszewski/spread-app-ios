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
        let timestamp = nowProvider()
        let previousAssignments = storedTaskAssignments(id: task.id) ?? []

        enqueueTaskMutation(task, operation: operation, timestamp: timestamp)
        enqueueTaskAssignmentMutations(
            taskId: task.id,
            previousAssignments: previousAssignments,
            currentAssignments: task.assignments,
            timestamp: timestamp
        )
        modelContext.insert(task)
        try modelContext.save()
    }

    func delete(_ task: DataModel.Task) async throws {
        let timestamp = nowProvider()
        let previousAssignments = storedTaskAssignments(id: task.id) ?? task.assignments

        enqueueTaskMutation(task, operation: .delete, timestamp: timestamp)
        enqueueTaskAssignmentTombstones(
            previousAssignments,
            taskId: task.id,
            timestamp: timestamp
        )
        modelContext.delete(task)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        static let changedFields = ["title", "date", "period", "status"]
        static let assignmentChangedFields = ["period", "date", "status"]
    }

    private func enqueueTaskMutation(
        _ task: DataModel.Task,
        operation: SyncOperation,
        timestamp: Date
    ) {
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

    private func enqueueTaskAssignmentMutations(
        taskId: UUID,
        previousAssignments: [TaskAssignment],
        currentAssignments: [TaskAssignment],
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

            enqueueTaskAssignmentMutation(
                assignment,
                taskId: taskId,
                operation: operation,
                timestamp: timestamp
            )
        }

        enqueueTaskAssignmentTombstones(
            Array(previousByID.values),
            taskId: taskId,
            timestamp: timestamp
        )
    }

    private func enqueueTaskAssignmentTombstones(
        _ assignments: [TaskAssignment],
        taskId: UUID,
        timestamp: Date
    ) {
        for assignment in assignments {
            enqueueTaskAssignmentMutation(
                assignment,
                taskId: taskId,
                operation: .delete,
                timestamp: timestamp
            )
        }
    }

    private func enqueueTaskAssignmentMutation(
        _ assignment: TaskAssignment,
        taskId: UUID,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        guard let recordData = SyncSerializer.serializeTaskAssignment(
            assignment,
            taskId: taskId,
            deviceId: deviceId,
            timestamp: timestamp,
            deletedAt: deletedAt
        ) else {
            return
        }

        let mutation = DataModel.SyncMutation(
            entityType: SyncEntityType.taskAssignment.rawValue,
            entityId: assignment.id,
            operation: operation.rawValue,
            recordData: recordData,
            changedFields: operation == .delete ? [] : Constants.assignmentChangedFields
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

    private func storedTaskAssignments(id: UUID) -> [TaskAssignment]? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<DataModel.Task>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.assignments
    }
}
