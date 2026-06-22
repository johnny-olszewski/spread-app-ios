import Foundation
import SwiftData

/// SwiftData implementation of `ChangeAwareTaskRepository`.
///
/// Diffs sync-outbox mutations from the caller-supplied `EntityChange` instead of
/// re-fetching pre-mutation state through a throwaway `ModelContext`, as
/// `SwiftDataTaskRepository` does. Create-vs-update is read from `change.isNew`
/// rather than a `fetchCount` query.
@MainActor
final class SwiftDataChangeAwareTaskRepository: ChangeAwareTaskRepository {

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

    // MARK: - ChangeAwareTaskRepository

    /// Fetches all tasks from the store, ordered by creation date.
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

    /// Persists `task` and enqueues sync-outbox mutations for the task, its assignments, and
    /// its tags, diffing against `change` rather than re-fetching pre-mutation state from disk.
    func save(_ task: DataModel.Task, change: EntityChange<TaskAssignment>) async throws {
        let operation: SyncOperation = change.isNew ? .create : .update
        let timestamp = nowProvider()

        enqueueTaskMutation(task, operation: operation, timestamp: timestamp)
        enqueueTaskAssignmentMutations(
            taskId: task.id,
            previousAssignments: change.previousAssignments,
            currentAssignments: task.assignments,
            timestamp: timestamp
        )
        enqueueTaskTagMutations(
            taskId: task.id,
            previousTagIds: change.previousTagIDs,
            currentTagIds: task.tags.map(\.id),
            timestamp: timestamp
        )
        modelContext.insert(task)
        try modelContext.save()
    }

    /// Deletes `task` and enqueues tombstone mutations for the task, its assignments, and tags.
    func delete(_ task: DataModel.Task) async throws {
        let timestamp = nowProvider()

        enqueueTaskMutation(task, operation: .delete, timestamp: timestamp)
        enqueueTaskAssignmentTombstones(task.assignments, taskId: task.id, timestamp: timestamp)
        enqueueTaskTagTombstones(tagIds: task.tags.map(\.id), taskId: task.id, timestamp: timestamp)
        modelContext.delete(task)
        try modelContext.save()
    }

    // MARK: - Outbox

    private enum Constants {
        /// Fields reported as changed on every non-delete task mutation.
        static let changedFields = [
            "title", "body", "priority", "due_date", "list_id",
            "date", "period", "status"
        ]
        /// Fields reported as changed on every non-delete task-assignment mutation.
        static let assignmentChangedFields = ["period", "date", "status"]
    }

    /// Serializes `task` and enqueues a single sync-outbox mutation for it.
    private func enqueueTaskMutation(
        _ task: DataModel.Task,
        operation: SyncOperation,
        timestamp: Date
    ) {
        let deletedAt = operation == .delete ? timestamp : nil
        // TODO: SPRD-250 - replace serializeTask and the hardcoded entityType below with a
        // `SerializableData` conformance on `DataModel.Task`.
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

    /// Diffs `previousAssignments` against `currentAssignments` by ID, enqueueing a create
    /// mutation for additions, an update mutation for changed assignments, and a tombstone for
    /// any previous assignment no longer present in `currentAssignments`.
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

    /// Enqueues a delete mutation for each of `assignments`.
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

    /// Serializes `assignment` and enqueues a single sync-outbox mutation for it.
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

    /// Diffs `previousTagIds` against `currentTagIds`, enqueueing a create mutation for each
    /// newly-added tag and a tombstone for each removed tag.
    private func enqueueTaskTagMutations(
        taskId: UUID,
        previousTagIds: [UUID],
        currentTagIds: [UUID],
        timestamp: Date
    ) {
        let previousSet = Set(previousTagIds)
        let currentSet = Set(currentTagIds)

        for tagId in currentSet.subtracting(previousSet) {
            guard let recordData = SyncSerializer.serializeTaskTag(
                taskId: taskId, tagId: tagId, timestamp: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.taskTag.rawValue,
                entityId: UUID(),
                operation: SyncOperation.create.rawValue,
                recordData: recordData
            )
            modelContext.insert(mutation)
        }

        enqueueTaskTagTombstones(
            tagIds: Array(previousSet.subtracting(currentSet)),
            taskId: taskId,
            timestamp: timestamp
        )
    }

    /// Enqueues a delete mutation for each tag ID in `tagIds`.
    private func enqueueTaskTagTombstones(tagIds: [UUID], taskId: UUID, timestamp: Date) {
        for tagId in tagIds {
            guard let recordData = SyncSerializer.serializeTaskTag(
                taskId: taskId, tagId: tagId, timestamp: timestamp, deletedAt: timestamp
            ) else { continue }
            let mutation = DataModel.SyncMutation(
                entityType: SyncEntityType.taskTag.rawValue,
                entityId: UUID(),
                operation: SyncOperation.delete.rawValue,
                recordData: recordData
            )
            modelContext.insert(mutation)
        }
    }
}
