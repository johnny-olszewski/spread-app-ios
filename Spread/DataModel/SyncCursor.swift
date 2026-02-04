import Foundation
import SwiftData

/// Extension adding sync cursor model to the data model schema.
extension DataModelSchemaV1 {

    /// Tracks the last-synced revision per server table for incremental pull.
    ///
    /// Each syncable table has its own cursor. During pull, the engine queries
    /// rows with `revision > lastRevision` to fetch only new/updated records.
    @Model
    final class SyncCursor {
        /// Unique identifier for this cursor.
        @Attribute(.unique) var id: UUID

        /// The server table name (e.g., "tasks", "spreads").
        var tableName: String

        /// The highest revision number seen from the server for this table.
        ///
        /// Zero means no data has been pulled yet.
        var lastRevision: Int64

        /// When the last successful pull occurred for this table.
        var lastSyncDate: Date

        init(
            id: UUID = UUID(),
            tableName: String,
            lastRevision: Int64 = 0,
            lastSyncDate: Date = .distantPast
        ) {
            self.id = id
            self.tableName = tableName
            self.lastRevision = lastRevision
            self.lastSyncDate = lastSyncDate
        }
    }
}
