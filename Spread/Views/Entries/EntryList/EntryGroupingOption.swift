import Foundation

/// A user-selectable strategy for partitioning a flat entry list into `EntryList.Section`s.
///
/// Shared across every spread (Day/Month/Year/Multiday) rather than bespoke per spread,
/// since list/tag/status are universal `Entry`/`Task`/`Note` attributes, not spread-specific
/// concepts. `String`-backed so it works directly with `@AppStorage`.
enum EntryGroupingOption: String, CaseIterable, Identifiable {
    case none
    case list
    case tag
    case status

    var id: String { rawValue }

    /// Display label for use in `EntryListOptionsPicker`.
    var displayName: String {
        switch self {
        case .none: "None"
        case .list: "List"
        case .tag: "Tag"
        case .status: "Status"
        }
    }

    /// Builds the partitioning recipe for this option.
    ///
    /// `date`/`creationPeriod`/`creationDate` describe the spread context each produced
    /// section should carry — the same per-spread metadata callers already pass to
    /// `EntryList.Section.init` directly. The bucket key itself comes entirely from each
    /// entry (`Entry.assignedList`/`.assignedTags`/`.status`), with no external lookup —
    /// list/tag are stored directly on `Task`/`Note`, not behind a `JournalManager` lookup.
    func grouping(date: Date, creationPeriod: Period, creationDate: Date) -> EntryList.Grouping<String> {
        EntryList.Grouping<String>(
            key: { [self] entry in key(for: entry) },
            sortedKeys: Self.sortedKeysUntitledLast,
            section: { [self] key, entries in
                EntryList.Section(
                    id: key,
                    title: self == .none ? "" : key,
                    date: date,
                    entries: entries,
                    creationPeriod: creationPeriod,
                    creationDate: creationDate
                )
            }
        )
    }

    // MARK: - Key extraction

    private static let untitled = "Untitled"

    private func key(for entry: any Entry) -> String {
        switch self {
        case .none: "all"
        case .list: entry.assignedList?.name ?? Self.untitled
        case .tag: entry.assignedTags.first?.name ?? Self.untitled
        case .status: entry.status.displayName
        }
    }

    /// Orders bucket keys alphabetically, with the "Untitled" fallback bucket always last.
    private static func sortedKeysUntitledLast(_ keys: [String]) -> [String] {
        keys.sorted { lhs, rhs in
            if lhs == untitled { return false }
            if rhs == untitled { return true }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}
