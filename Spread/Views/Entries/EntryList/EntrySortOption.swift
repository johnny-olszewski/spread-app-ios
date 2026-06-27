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

    var id: String { rawValue }

    /// Display label for use in `EntryListOptionsPicker`.
    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .priority: "Priority"
        case .dueDate: "Due Date"
        case .title: "Title"
        }
    }

    /// The within-bucket ordering comparator for this option, or `nil` for `.manual`
    /// (preserves the incoming order — see `EntryList.Section.grouped(from:by:orderedBy:)`).
    var areInOrder: ((any Entry, any Entry) -> Bool)? {
        switch self {
        case .manual:
            return nil
        case .priority:
            return { Self.priorityRank($0.displayPriority) > Self.priorityRank($1.displayPriority) }
        case .dueDate:
            return { $0.sortDate < $1.sortDate }
        case .title:
            return { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    /// `DataModel.Task.Priority` isn't `Comparable`; its case declaration order
    /// (`none`/`low`/`medium`/`high`) is already the intended ascending rank.
    private static func priorityRank(_ priority: DataModel.Task.Priority) -> Int {
        DataModel.Task.Priority.allCases.firstIndex(of: priority) ?? 0
    }
}
