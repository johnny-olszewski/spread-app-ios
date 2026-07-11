import Foundation

/// A user-selectable within-section ordering for entries, orthogonal to `EntryGroupingOption`.
///
/// Built directly on `Entry` protocol properties (`displayPriority`/`sortDate`/`title`) — no
/// per-type casting needed, unlike grouping by list/tag. `String`-backed so it works directly
/// with `@AppStorage`.
enum EntrySortOption: String, CaseIterable, Identifiable {
    case manual
    case priority
    case dueDate
    case title
    case type
    case time

    var id: String { rawValue }

    /// The options every spread offers. `.time` is excluded: a scheduled time is only
    /// meaningful on a day spread, so only Day passes `allCases` to
    /// `EntryListOptionsPicker`. See `Documentation/Specs/TaskScheduledTime.md`. [SPRD-301]
    static var universalOptions: [EntrySortOption] {
        allCases.filter { $0 != .time }
    }

    /// Display label for use in `EntryListOptionsPicker`.
    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .title: "Title"
        case .type: "Type"
        case .time: "Time"
        }
    }

    /// The within-bucket ordering comparator for this option, or `nil` for `.manual`
    /// (preserves the incoming order — see `EntryList.Section.grouped(from:by:orderedBy:)`).
    ///
    /// Every non-`.manual`, non-`.title` option breaks ties on its primary key by title,
    /// alphabetically — without this, two same-priority/same-due-date/same-type entries
    /// would fall back to whatever order `sorted(by:)` happened to preserve them in, which
    /// is unspecified and not what a user picking "sort by X" expects.
    var areInOrder: ((any Entry, any Entry) -> Bool)? {
        switch self {
        case .manual:
            return nil
        case .priority:
            return Self.withTitleTiebreaker { Self.priorityRank($0.displayPriority) > Self.priorityRank($1.displayPriority) }
        case .dueDate:
            return Self.withTitleTiebreaker { $0.sortDate < $1.sortDate }
        case .title:
            return Self.titleAscending
        case .type:
            return Self.withTitleTiebreaker { Self.typeRank($0.entryType) < Self.typeRank($1.entryType) }
        case .time:
            // Timed entries chronological by `scheduledStart` (absolute instants, so the
            // ordering is timezone-invariant across mixed types); untimed entries after
            // all timed ones. [SPRD-301]
            return Self.withTitleTiebreaker { lhs, rhs in
                switch (lhs.scheduledStart, rhs.scheduledStart) {
                case let (lhsStart?, rhsStart?): lhsStart < rhsStart
                case (.some, nil): true
                case (nil, .some), (nil, nil): false
                }
            }
        }
    }

    /// `DataModel.Task.Priority` isn't `Comparable`; its case declaration order
    /// (`none`/`low`/`medium`/`high`) is already the intended ascending rank.
    private static func priorityRank(_ priority: DataModel.Task.Priority) -> Int {
        DataModel.Task.Priority.allCases.firstIndex(of: priority) ?? 0
    }

    /// `EntryType` isn't `Comparable`; its case declaration order (`task`/`event`/`note`)
    /// is used as the intended ascending rank.
    private static func typeRank(_ entryType: EntryType) -> Int {
        EntryType.allCases.firstIndex(of: entryType) ?? 0
    }

    private static let titleAscending: (any Entry, any Entry) -> Bool = {
        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }

    /// Wraps `primary` so that when it considers two entries equivalent (neither sorts
    /// before the other), the result falls back to alphabetical title order instead of
    /// leaving the tie unresolved.
    private static func withTitleTiebreaker(
        _ primary: @escaping (any Entry, any Entry) -> Bool
    ) -> (any Entry, any Entry) -> Bool {
        { lhs, rhs in
            if primary(lhs, rhs) { return true }
            if primary(rhs, lhs) { return false }
            return titleAscending(lhs, rhs)
        }
    }
}
