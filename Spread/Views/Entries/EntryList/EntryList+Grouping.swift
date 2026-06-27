import Foundation
import SwiftUI

extension EntryList {
    /// A closure-based recipe for partitioning a flat entry list into `EntryList.Section`s.
    ///
    /// `key` is closure-based rather than a `KeyPath` or a fixed enum because grouping keys
    /// are often derived from external state (e.g. an entry's assigned list, looked up
    /// through `JournalManager`), not just stored `Entry` properties. `EntryListView` never
    /// sees a `Grouping` directly — it only ever renders the `[EntryList.Section]` produced
    /// by `EntryList.Section.grouped(from:by:orderedBy:)`.
    struct Grouping<Key: Hashable> {
        /// Derives the bucket key for a given entry.
        let key: (any Entry) -> Key

        /// Orders the bucket keys that should be rendered, given the keys actually
        /// present after bucketing. May include keys with no matching entries — any
        /// such key is silently omitted from the result.
        let sortedKeys: ([Key]) -> [Key]

        /// Builds the rendered section for one bucket, given its key and ordered entries.
        let section: (Key, [any Entry]) -> EntryList.Section
    }
}

extension EntryList.Section {
    /// Partitions a flat entry list into sections using `grouping`, independently ordering
    /// each bucket's entries via `areInOrder` before building its section.
    ///
    /// Grouping (which bucket an entry belongs to) and ordering (the sequence of entries
    /// within a bucket) are orthogonal — e.g. "group by list, order by priority" is
    /// expressed by combining an `EntryList.Grouping<DataModel.List?>`-style grouping with
    /// a priority comparator here. A bucket key with no matching entries is omitted.
    ///
    /// - Parameters:
    ///   - entries: The flat entry list to partition.
    ///   - grouping: The bucketing recipe.
    ///   - areInOrder: An optional within-bucket ordering comparator. `nil` preserves
    ///     each bucket's incoming order.
    /// - Returns: One section per non-empty bucket, in `grouping.sortedKeys` order.
    static func grouped<Key: Hashable>(
        from entries: [any Entry],
        by grouping: EntryList.Grouping<Key>,
        orderedBy areInOrder: ((any Entry, any Entry) -> Bool)? = nil
    ) -> [EntryList.Section] {
        let buckets = Dictionary(grouping: entries, by: grouping.key)
        return grouping.sortedKeys(Array(buckets.keys)).compactMap { key in
            guard let bucketEntries = buckets[key], !bucketEntries.isEmpty else { return nil }
            let orderedEntries = areInOrder.map { bucketEntries.sorted(by: $0) } ?? bucketEntries
            return grouping.section(key, orderedEntries)
        }
    }
}

extension EntryListView {
    /// Renders a flat entry list, partitioned into sections by `grouping` and ordered
    /// within each section by `areInOrder`.
    ///
    /// Equivalent to calling `EntryList.Section.grouped(from:by:orderedBy:)` and passing
    /// the result to the `sections:` initializer — provided as a convenience for callers
    /// with a single grouping recipe. Callers needing hybrid composition (e.g. a pinned,
    /// ungrouped section alongside grouped ones) should call `grouped(from:by:orderedBy:)`
    /// directly and concatenate with their own sections before using the `sections:` init.
    init<Key: Hashable>(
        entries: [any Entry],
        groupedBy grouping: EntryList.Grouping<Key>,
        orderedBy areInOrder: ((any Entry, any Entry) -> Bool)? = nil,
        configurationMap: EntryRowView.ConfigurationMap,
        @ViewBuilder sectionHeaderTrailingContent: @escaping (EntryList.Section) -> TrailingContent
    ) {
        self.init(
            sections: EntryList.Section.grouped(from: entries, by: grouping, orderedBy: areInOrder),
            configurationMap: configurationMap,
            sectionHeaderTrailingContent: sectionHeaderTrailingContent
        )
    }

    /// Convenience overload of `init(entries:groupedBy:orderedBy:configurationMap:sectionHeaderTrailingContent:)`
    /// for callers with no section header trailing content.
    init<Key: Hashable>(
        entries: [any Entry],
        groupedBy grouping: EntryList.Grouping<Key>,
        orderedBy areInOrder: ((any Entry, any Entry) -> Bool)? = nil,
        configurationMap: EntryRowView.ConfigurationMap
    ) where TrailingContent == EmptyView {
        self.init(
            sections: EntryList.Section.grouped(from: entries, by: grouping, orderedBy: areInOrder),
            configurationMap: configurationMap
        )
    }
}
