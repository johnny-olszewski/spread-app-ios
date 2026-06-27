import Foundation
import SwiftData

extension ModelContext {
    /// Enqueues a sync-outbox mutation, coalescing it with any existing unsent mutation for
    /// the same `(entityType, entityId)` instead of inserting a duplicate row.
    ///
    /// See `Documentation/Specs/Sync.md`'s "Outbox Mutation Coalescing": each mutation's
    /// `recordData` is a full entity snapshot, so the latest pending mutation for an entity
    /// already supersedes any earlier unsent one. An unsent `create` is never downgraded to
    /// `update` by a later mutation; a `delete` always wins outright. Coalescing only ever
    /// considers currently-unsent rows — once `SyncEngine.push()` deletes a pushed row, the
    /// next mutation for that entity starts a fresh one.
    func enqueueCoalescedSyncMutation(
        entityType: String,
        entityId: UUID,
        operation: SyncOperation,
        recordData: Data,
        changedFields: [String] = []
    ) {
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            predicate: #Predicate { $0.entityType == entityType && $0.entityId == entityId }
        )

        guard let existing = try? fetch(descriptor).first else {
            insert(DataModel.SyncMutation(
                entityType: entityType,
                entityId: entityId,
                operation: operation.rawValue,
                recordData: recordData,
                changedFields: changedFields
            ))
            return
        }

        let resolvedOperation: SyncOperation =
            operation == .delete ? .delete
            : existing.operation == SyncOperation.create.rawValue ? .create
            : operation

        existing.operation = resolvedOperation.rawValue
        existing.recordData = recordData
        existing.changedFields = operation == .delete ? [] : changedFields
        existing.createdDate = .now
        existing.retryCount = 0
    }
}
