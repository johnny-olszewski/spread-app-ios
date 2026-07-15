import Foundation

/// A user-selectable within-section ordering for entries, orthogonal to `EntryGroupingOption`.
///
/// Built directly on `Entry` protocol properties (`scheduledStart`/`displayPriority`/`dueDate`/
/// `entryType`/`title`/`createdDate`) — no per-type casting needed, unlike grouping by list/tag.
/// `String`-backed so it works directly with `@AppStorage`.
///
/// Every option resolves ties through the full **Default chain** (`scheduledStart` nil-last →
/// title → `createdDate`), so any option's output is identical for any input permutation —
/// `createdDate` is effectively unique, making the chain a total order. [SPRD-307]
enum EntrySortOption: String, CaseIterable, Identifiable {
    case `default`
    case priority
    case dueDate
    case type

    var id: String { rawValue }

    /// Display label for use in `EntryListOptionsPicker`.
    var displayName: String {
        switch self {
        case .default: "Default"
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .type: "Type"
        }
    }

    /// The within-bucket ordering comparator for this option.
    ///
    /// `.default` is the chain itself: timed entries first, chronological by `scheduledStart`
    /// (absolute instants, so the ordering is timezone-invariant across mixed types), then
    /// untimed entries alphabetically by title, with `createdDate` breaking title ties.
    /// Every other option applies its primary key and falls through the entire Default
    /// chain on ties.
    var areInOrder: (any Entry, any Entry) -> Bool {
        switch self {
        case .default:
            return Self.defaultChain
        case .priority:
            return Self.withDefaultTiebreaker { Self.priorityRank($0.displayPriority) > Self.priorityRank($1.displayPriority) }
        case .dueDate:
            // The task's actual due date, soonest first; entries without one (including
            // all events and notes) sort after all due-dated entries. [SPRD-307]
            return Self.withDefaultTiebreaker { Self.compareNilLast($0.dueDate, $1.dueDate) == .orderedAscending }
        case .type:
            return Self.withDefaultTiebreaker { Self.typeRank($0.entryType) < Self.typeRank($1.entryType) }
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

    /// The Default chain: `scheduledStart` ascending with non-nil before nil, then title
    /// (localized, case-insensitive) ascending, then `createdDate` ascending.
    private static let defaultChain: (any Entry, any Entry) -> Bool = { lhs, rhs in
        let time = compareNilLast(lhs.scheduledStart, rhs.scheduledStart)
        if time != .orderedSame { return time == .orderedAscending }
        let title = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if title != .orderedSame { return title == .orderedAscending }
        return lhs.createdDate < rhs.createdDate
    }

    /// Three-way compare with `nil` ordered after every non-nil value.
    private static func compareNilLast<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs < rhs { return .orderedAscending }
            if lhs > rhs { return .orderedDescending }
            return .orderedSame
        case (.some, nil): return .orderedAscending
        case (nil, .some): return .orderedDescending
        case (nil, nil): return .orderedSame
        }
    }

    /// Wraps `primary` so that when it considers two entries equivalent (neither sorts
    /// before the other), the result falls through the entire Default chain instead of
    /// leaving the tie unresolved.
    private static func withDefaultTiebreaker(
        _ primary: @escaping (any Entry, any Entry) -> Bool
    ) -> (any Entry, any Entry) -> Bool {
        { lhs, rhs in
            if primary(lhs, rhs) { return true }
            if primary(rhs, lhs) { return false }
            return defaultChain(lhs, rhs)
        }
    }
}
