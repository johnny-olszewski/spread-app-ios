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
    case type

    var id: String { rawValue }

    /// Display label for use in `EntryListOptionsPicker`.
    var displayName: String {
        switch self {
        case .none: "None"
        case .list: "List"
        case .tag: "Tag"
        case .status: "Status"
        case .type: "Type"
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
        let nilLabel = nilBucketLabel
        return EntryList.Grouping<String>(
            key: { [self] entry in key(for: entry) },
            sortedKeys: { keys in Self.sortedNilBucketLast(keys, nilLabel: nilLabel) },
            section: { [self] key, entries in
                let isNilBucket = nilLabel != nil && key == nilLabel
                return EntryList.Section(
                    id: key,
                    title: self == .none ? "" : key,
                    date: date,
                    entries: entries,
                    creationPeriod: creationPeriod,
                    creationDate: creationDate,
                    headerStyle: isNilBucket ? .unnamed : .named
                )
            }
        )
    }

    // MARK: - Key extraction

    /// The display label used for entries that have no assigned value for this grouping.
    /// `nil` for grouping modes where every entry always has a value (.none, .status, .type).
    private var nilBucketLabel: String? {
        switch self {
        case .none, .status, .type: nil
        case .list: "No list"
        case .tag: "No tag"
        }
    }

    private func key(for entry: any Entry) -> String {
        switch self {
        case .none: "all"
        case .list: entry.assignedList?.name ?? "No list"
        case .tag: entry.assignedTags.first?.name ?? "No tag"
        case .status: entry.status.displayName
        case .type: entry.entryType.displayName
        }
    }

    /// Orders bucket keys alphabetically, with the nil-bucket label always last.
    private static func sortedNilBucketLast(_ keys: [String], nilLabel: String?) -> [String] {
        keys.sorted { lhs, rhs in
            if let nilLabel {
                if lhs == nilLabel { return false }
                if rhs == nilLabel { return true }
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}
