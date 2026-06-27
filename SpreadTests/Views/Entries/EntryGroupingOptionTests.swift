import Foundation
import Testing
@testable import Spread

/// Tests for `EntryGroupingOption`'s bucketing behavior.
@Suite("Entry Grouping Option Tests")
struct EntryGroupingOptionTests {

    private let today = Date()

    private func sections(for entries: [any Entry], option: EntryGroupingOption) -> [EntryList.Section] {
        EntryList.Section.grouped(from: entries, by: option.grouping(date: today, creationPeriod: .day, creationDate: today))
    }

    // `.list` buckets entries by their assigned list name, with unassigned entries
    // falling into an "Untitled" bucket.
    // Expected: named-list buckets appear (alphabetical), "Untitled" bucket last.
    @Test func testListGroupsByAssignedListWithUntitledFallback() {
        let listA = DataModel.List(name: "Alpha")
        let listB = DataModel.List(name: "Beta")
        let entries: [any Entry] = [
            DataModel.Task(title: "A Task", date: today, list: listA),
            DataModel.Task(title: "B Task", date: today, list: listB),
            DataModel.Task(title: "Unlisted Task", date: today)
        ]

        let result = sections(for: entries, option: .list)

        #expect(result.map(\.id) == ["Alpha", "Beta", "Untitled"])
        #expect(result[0].entries.map(\.title) == ["A Task"])
        #expect(result[1].entries.map(\.title) == ["B Task"])
        #expect(result[2].entries.map(\.title) == ["Unlisted Task"])
    }

    // `.tag` buckets by the entry's first tag only — an entry with multiple tags
    // appears in exactly one bucket (its first tag's), not fanned out into every tag.
    // Expected: a 2-tagged task appears once, under its first tag's bucket.
    @Test func testTagGroupsByFirstTagOnly() {
        let tagX = DataModel.Tag(name: "X")
        let tagY = DataModel.Tag(name: "Y")
        let entries: [any Entry] = [
            DataModel.Task(title: "Multi-tag Task", date: today, tags: [tagX, tagY]),
            DataModel.Task(title: "Untagged Task", date: today)
        ]

        let result = sections(for: entries, option: .tag)

        #expect(result.map(\.id) == ["X", "Untitled"])
        #expect(result[0].entries.map(\.title) == ["Multi-tag Task"])
        #expect(result[1].entries.map(\.title) == ["Untagged Task"])
        // The multi-tag task appears in exactly one section overall.
        let allTitles: [String] = result.flatMap { section in section.entries.map { $0.title } }
        let occurrences = allTitles.filter { $0 == "Multi-tag Task" }
        #expect(occurrences.count == 1)
    }

    // `.status` buckets entries by their `EntryStatus.displayName`.
    // Expected: open and complete tasks land in separate, correctly-named buckets.
    @Test func testStatusGroupsByStatusDisplayName() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Open Task", date: today, status: .open),
            DataModel.Task(title: "Done Task", date: today, status: .complete)
        ]

        let result = sections(for: entries, option: .status)

        #expect(result.map(\.id).sorted() == ["Complete", "Open"])
        #expect(result.first { $0.id == "Open" }?.entries.map(\.title) == ["Open Task"])
        #expect(result.first { $0.id == "Complete" }?.entries.map(\.title) == ["Done Task"])
    }

    // `.none` produces a single bucket containing every entry, regardless of
    // list/tag/status differences.
    // Expected: exactly one section containing all input entries.
    @Test func testNoneProducesSingleBucketWithAllEntries() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: today),
            DataModel.Task(title: "Task 2", date: today, status: .complete),
            DataModel.Note(title: "Note 1", date: today)
        ]

        let result = sections(for: entries, option: .none)

        #expect(result.count == 1)
        #expect(result[0].entries.count == 3)
    }
}

/// Tests for `EntrySortOption`'s within-bucket ordering comparators.
@Suite("Entry Sort Option Tests")
struct EntrySortOptionTests {

    private let today = Date()

    // `.manual` exposes no comparator — callers should preserve incoming order.
    // Expected: `areInOrder` is `nil`.
    @Test func testManualHasNoComparator() {
        #expect(EntrySortOption.manual.areInOrder == nil)
    }

    // `.priority` orders entries from highest to lowest priority.
    // Expected: high priority sorts before low.
    @Test func testPriorityOrdersHighestFirst() {
        let high = DataModel.Task(title: "High", priority: .high, date: today)
        let low = DataModel.Task(title: "Low", priority: .low, date: today)
        let areInOrder = EntrySortOption.priority.areInOrder!

        #expect(areInOrder(high, low))
        #expect(!areInOrder(low, high))
    }

    // `.dueDate` orders entries chronologically by `sortDate`.
    // Expected: an earlier-dated entry sorts before a later-dated one.
    @Test func testDueDateOrdersChronologically() {
        let earlier = DataModel.Task(title: "Earlier", date: today)
        let later = DataModel.Task(title: "Later", date: today.addingTimeInterval(3600))
        let areInOrder = EntrySortOption.dueDate.areInOrder!

        #expect(areInOrder(earlier, later))
        #expect(!areInOrder(later, earlier))
    }

    // `.title` orders entries alphabetically (case-insensitive) by title.
    // Expected: "Alpha" sorts before "beta" despite differing case.
    @Test func testTitleOrdersAlphabeticallyCaseInsensitive() {
        let alpha = DataModel.Task(title: "Alpha", date: today)
        let beta = DataModel.Task(title: "beta", date: today)
        let areInOrder = EntrySortOption.title.areInOrder!

        #expect(areInOrder(alpha, beta))
        #expect(!areInOrder(beta, alpha))
    }
}
