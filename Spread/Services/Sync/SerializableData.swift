import Foundation

/// Lets a syncable entity own its own outbox serialization and server entity-type lookup,
/// instead of `SyncSerializer` and each repository call site hand-mapping both separately.
///
/// - TODO: [SPRD-252] Only `DataModel.Task` conforms today. The remaining syncable types
///   (`Note`, `Spread`, `List`, `Tag`, `Collection`, `Settings`, `Assignment`, entry-tag rows)
///   are expected to gain their own conformances in follow-up tasks, at which point
///   `SyncSerializer`'s corresponding static `serialize*` functions and repositories'
///   hardcoded `SyncEntityType` literals can be retired.
protocol SerializableData {
    /// The server-side entity type this conformer syncs as.
    static var entityType: SyncEntityType { get }

    /// Serializes `self` into JSON record data for the outbox.
    ///
    /// - Parameters:
    ///   - deviceId: The originating device, recorded on the record for LWW conflict resolution.
    ///   - timestamp: The mutation timestamp, used as a fallback for any field-level
    ///     `*UpdatedAt` value that hasn't been set yet.
    ///   - deletedAt: Non-nil for a delete-operation mutation; overrides the entity's own
    ///     `deletedAt` if present.
    func serialize(deviceId: UUID, timestamp: Date, deletedAt: Date?) -> Data?
}
