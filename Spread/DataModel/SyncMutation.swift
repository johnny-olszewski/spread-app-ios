import Foundation
import SwiftData

/// Extension adding sync infrastructure models to the data model schema.
extension DataModelSchemaV1 {

    /// An outbox entry representing a local change that needs to be pushed to the server.
    ///
    /// Each mutation captures the full record data and changed fields at the time
    /// of the local write. Mutations are processed in creation order with parent
    /// entities pushed before children (e.g., spreads before task_assignments).
    @Model
    final class SyncMutation {
        /// Unique identifier for this mutation.
        @Attribute(.unique) var id: UUID

        /// The server table this mutation targets (e.g., "tasks", "spreads").
        var entityType: String

        /// The ID of the entity being mutated.
        var entityId: UUID

        /// The operation type: "create", "update", or "delete".
        var operation: String

        /// JSON-encoded record data containing all fields needed for the merge RPC.
        ///
        /// Stored as a complete snapshot so the push can reconstruct the RPC call
        /// without needing to re-read the entity (which may have changed since).
        var recordData: Data

        /// Which fields were changed in this mutation.
        ///
        /// Used to set appropriate `_updated_at` timestamps for field-level LWW.
        /// For creates, this contains all fields. For deletes, this is empty.
        var changedFields: [String]

        /// When this mutation was created.
        ///
        /// Used for ordering (FIFO) and as the `_updated_at` timestamp for
        /// changed fields when per-field tracking is not yet available (SPRD-87).
        var createdDate: Date

        /// Number of failed push attempts.
        ///
        /// Used for exponential backoff. Reset to 0 on successful push.
        var retryCount: Int

        init(
            id: UUID = UUID(),
            entityType: String,
            entityId: UUID,
            operation: String,
            recordData: Data,
            changedFields: [String] = [],
            createdDate: Date = .now,
            retryCount: Int = 0
        ) {
            self.id = id
            self.entityType = entityType
            self.entityId = entityId
            self.operation = operation
            self.recordData = recordData
            self.changedFields = changedFields
            self.createdDate = createdDate
            self.retryCount = retryCount
        }
    }
}
