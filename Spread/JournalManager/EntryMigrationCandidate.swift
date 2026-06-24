import Foundation

/// An entry eligible to migrate to a destination spread, generic over any `AssignableEntry`.
///
/// Generalizes the legacy concrete `MigrationCandidate` (which is `Task`-only) so the same
/// shape is reusable if another `AssignableEntry` type ever gains migration planning. Only
/// needs `entry.id` from its generic parameter — no other `AssignableEntry`-specific access —
/// so it stays valid regardless of how `AssignableEntry`'s requirements evolve.
struct EntryMigrationCandidate<E: AssignableEntry>: Identifiable {
    /// The entry eligible for migration.
    let entry: E

    /// The spread the entry is currently assigned to, if any.
    ///
    /// `nil` when the source is Inbox (the entry has no matching spread assignment).
    let sourceSpread: DataModel.Spread?

    /// The target spread this entry should be migrated to.
    let destination: DataModel.Spread

    /// Identifies where the entry currently lives — Inbox when `sourceSpread` is `nil`,
    /// otherwise the spread itself. Derived from `sourceSpread` rather than stored
    /// separately — `sourceSpread.date` is already normalized, so no `calendar` is needed.
    var sourceKey: TaskReviewSourceKey {
        guard let sourceSpread else {
            return TaskReviewSourceKey(kind: .inbox)
        }
        return TaskReviewSourceKey(
            kind: .spread(id: sourceSpread.id, period: sourceSpread.period, date: sourceSpread.date)
        )
    }

    /// A stable composite identifier combining entry, source, and destination.
    var id: String {
        "\(entry.id)-\(sourceKey.id)-\(destination.id.uuidString)"
    }
}
