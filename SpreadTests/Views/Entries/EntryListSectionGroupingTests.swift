import Foundation
import Testing
@testable import Spread

/// Tests for `EntryList.Grouping`, `EntryList.Section.grouped(from:by:orderedBy:)`, and the
/// `EntryListView.init(entries:groupedBy:orderedBy:...)` convenience initializers.
@Suite("EntryList Section Grouping Tests")
struct EntryListSectionGroupingTests {

    private let today = Date()

    private func makeSection(id: String, entries: [any Entry]) -> EntryList.Section {
        EntryList.Section(id: id, title: id, date: Date(), entries: entries, creationPeriod: .day, creationDate: Date())
    }

    // Entries are bucketed by the grouping's `key` closure, with one section produced per
    // distinct key value present in the input.
    // Expected: tasks split into "even"/"odd" buckets based on a sample key closure.
    @Test func testGroupedBucketsEntriesByKey() {
        let entries: [any Entry] = (1...4).map { DataModel.Task(title: "Task \($0)", date: Date(timeIntervalSince1970: TimeInterval($0))) }
        let grouping = EntryList.Grouping<String>(
            key: { entry in Int(entry.title.split(separator: " ").last ?? "0")! % 2 == 0 ? "even" : "odd" },
            sortedKeys: { keys in keys.sorted() },
            section: makeSection
        )

        let sections = EntryList.Section.grouped(from: entries, by: grouping)

        #expect(sections.map(\.id) == ["even", "odd"])
        #expect(sections[0].entries.map(\.title) == ["Task 2", "Task 4"])
        #expect(sections[1].entries.map(\.title) == ["Task 1", "Task 3"])
    }

    // Bucket order follows `sortedKeys`, not the order keys first appear in the input.
    // Expected: a reverse-alphabetical `sortedKeys` produces sections in that order.
    @Test func testGroupedOrdersBucketsBySortedKeys() {
        let entries: [any Entry] = [
            DataModel.Task(title: "A", date: today),
            DataModel.Task(title: "B", date: today),
            DataModel.Task(title: "C", date: today)
        ]
        let grouping = EntryList.Grouping<String>(
            key: { $0.title },
            sortedKeys: { keys in keys.sorted(by: >) },
            section: makeSection
        )

        let sections = EntryList.Section.grouped(from: entries, by: grouping)

        #expect(sections.map(\.id) == ["C", "B", "A"])
    }

    // `orderedBy` orders entries within each bucket without affecting which bucket an
    // entry is assigned to.
    // Expected: entries within the single bucket are sorted by title; bucketing is untouched.
    @Test func testGroupedOrdersEntriesWithinBucket() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Charlie", date: today),
            DataModel.Task(title: "Alpha", date: today),
            DataModel.Task(title: "Bravo", date: today)
        ]
        let grouping = EntryList.Grouping<String>(
            key: { _ in "all" },
            sortedKeys: { $0 },
            section: makeSection
        )

        let sections = EntryList.Section.grouped(from: entries, by: grouping, orderedBy: { $0.title < $1.title })

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.title) == ["Alpha", "Bravo", "Charlie"])
    }

    // A key returned by `sortedKeys` with no matching entries (e.g. a canonical key list
    // wider than what's actually present) is omitted from the result rather than producing
    // an empty section.
    // Expected: only the bucket with actual entries appears in the output.
    @Test func testGroupedOmitsEmptyBuckets() {
        let entries: [any Entry] = [DataModel.Task(title: "Solo", date: today)]
        let grouping = EntryList.Grouping<String>(
            key: { _ in "present" },
            sortedKeys: { _ in ["present", "absent"] },
            section: makeSection
        )

        let sections = EntryList.Section.grouped(from: entries, by: grouping)

        #expect(sections.map(\.id) == ["present"])
    }

    // `EntryListView.init(entries:groupedBy:orderedBy:configurationMap:)` is documented as
    // equivalent to calling `grouped(from:by:orderedBy:)` directly and passing the result
    // to the `sections:` initializer.
    // Expected: both paths produce identical sections for the same inputs.
    @Test func testEntryListViewGroupedInitMatchesStaticHelper() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Beta", date: today),
            DataModel.Task(title: "Alpha", date: today)
        ]
        let grouping = EntryList.Grouping<String>(
            key: { _ in "all" },
            sortedKeys: { $0 },
            section: makeSection
        )
        let areInOrder: (any Entry, any Entry) -> Bool = { $0.title < $1.title }

        let expectedSections = EntryList.Section.grouped(from: entries, by: grouping, orderedBy: areInOrder)
        let view = EntryListView(entries: entries, groupedBy: grouping, orderedBy: areInOrder, configurationMap: [:])

        #expect(view.sections.map(\.id) == expectedSections.map(\.id))
        #expect(view.sections.map { $0.entries.map(\.title) } == expectedSections.map { $0.entries.map(\.title) })
    }
}
