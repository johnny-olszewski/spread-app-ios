import Foundation
import SwiftData

/// Extension adding sync cursor model to the data model schema.
extension DataModelSchemaV1 {

    /// Tracks the last-synced revision per server table for incremental pull.
    ///
    /// Each syncable table has its own cursor. During pull, the engine queries
    /// rows with `revision > lastRevision` to fetch only new/updated records.
    ///
    /// `lastRevision` starts at `-1` so that the very first pull fetches
    /// `revision > -1`, which includes rows with `revision = 0`. Rows at
    /// revision 0 arise when records are inserted directly into Supabase
    /// (e.g. via the dashboard) rather than through the merge RPCs that
    /// auto-increment the revision. Starting at 0 would permanently skip them.
    @Model
    final class SyncCursor {
        /// Unique identifier for this cursor.
        @Attribute(.unique) var id: UUID

        /// The server table name (e.g., "tasks", "spreads").
        var tableName: String

        /// The highest revision number seen from the server for this table.
        ///
        /// `-1` means no data has been pulled yet (ensures revision-0 rows are included on first pull).
        var lastRevision: Int64

        /// When the last successful pull occurred for this table.
        var lastSyncDate: Date

        init(
            id: UUID = UUID(),
            tableName: String,
            lastRevision: Int64 = -1,
            lastSyncDate: Date = .distantPast
        ) {
            self.id = id
            self.tableName = tableName
            self.lastRevision = lastRevision
            self.lastSyncDate = lastSyncDate
        }
    }
}
