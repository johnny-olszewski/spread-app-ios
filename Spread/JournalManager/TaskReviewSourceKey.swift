import Foundation

/// Identifies the source of a task during migration or overdue-review flows.
///
/// A task can originate from the Inbox (no spread assignment) or from a specific
/// spread identified by its ID, period, and date. Used to track provenance when
/// moving tasks between spreads and to determine migration eligibility.
struct TaskReviewSourceKey: Hashable, Identifiable {
    /// The kind of source — either the Inbox or a concrete spread.
    enum Kind: Hashable {
        /// The task has no matching spread assignment and lives in the Inbox.
        case inbox
        /// The task has an open assignment on the spread with the given identity.
        case spread(id: UUID, period: Period, date: Date)
    }

    /// The source kind for this key.
    let kind: Kind

    /// A stable string identifier suitable for use as a SwiftUI `id`.
    var id: String {
        switch kind {
        case .inbox:
            return "inbox"
        case .spread(let id, _, _):
            return "spread-\(id.uuidString)"
        }
    }

    /// The period of the source spread, or `nil` when the source is Inbox.
    var period: Period? {
        switch kind {
        case .inbox:
            return nil
        case .spread(_, let period, _):
            return period
        }
    }

    /// The date of the source spread, or `nil` when the source is Inbox.
    var date: Date? {
        switch kind {
        case .inbox:
            return nil
        case .spread(_, _, let date):
            return date
        }
    }

    /// The granularity rank of the source, used to enforce forward-only migration.
    ///
    /// Inbox has rank 0. Spread ranks increase with period granularity (year < month < day).
    /// A migration destination must have a strictly higher rank than the source.
    var sourceRank: Int {
        period?.granularityRank ?? 0
    }
}
