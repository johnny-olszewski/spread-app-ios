import Foundation
import SwiftData

/// Extension adding assignment-repair marker storage to the data model schema.
extension DataModelSchemaV1 {

    /// Records that assignment-repair eligibility has already been evaluated for an entry/account.
    ///
    /// Used to ensure safe automatic backfill runs at most once per entry/account.
    @Model
    final class SyncRepairMarker {
        /// Unique marker key for `(accountId, entryType, entryId)`.
        @Attribute(.unique) var key: String

        /// Unique identifier for the marker record.
        @Attribute(.unique) var id: UUID

        /// The signed-in account the repair evaluation belongs to.
        var accountId: UUID

        /// Entry type: `task` or `note`.
        var entryType: String

        /// The task or note identifier.
        var entryId: UUID

        /// Whether a backfill was actually enqueued for this entry.
        var didBackfill: Bool

        /// When the marker was recorded.
        var createdDate: Date

        init(
            accountId: UUID,
            entryType: String,
            entryId: UUID,
            didBackfill: Bool,
            createdDate: Date = .now
        ) {
            self.id = UUID()
            self.accountId = accountId
            self.entryType = entryType
            self.entryId = entryId
            self.didBackfill = didBackfill
            self.createdDate = createdDate
            self.key = Self.makeKey(accountId: accountId, entryType: entryType, entryId: entryId)
        }

        static func makeKey(accountId: UUID, entryType: String, entryId: UUID) -> String {
            "\(accountId.uuidString)|\(entryType)|\(entryId.uuidString)"
        }
    }
}
