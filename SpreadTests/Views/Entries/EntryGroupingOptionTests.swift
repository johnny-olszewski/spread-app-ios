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
    // falling into a "No list" bucket (SPRD-287 nil-bucket label).
    // Expected: named-list buckets appear (alphabetical), "No list" bucket last.
    @Test func testListGroupsByAssignedListWithNoListFallback() {
        let listA = DataModel.List(name: "Alpha")
        let listB = DataModel.List(name: "Beta")
        let entries: [any Entry] = [
            DataModel.Task(title: "A Task", date: today, list: listA),
            DataModel.Task(title: "B Task", date: today, list: listB),
            DataModel.Task(title: "Unlisted Task", date: today)
        ]

        let result = sections(for: entries, option: .list)

        #expect(result.map(\.id) == ["Alpha", "Beta", "No list"])
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

        #expect(result.map(\.id) == ["X", "No tag"])
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

    // `.type` buckets entries by their `EntryType.displayName` — Task/Event/Note each
    // land in their own bucket.
    // Expected: three buckets, one per entry type, each containing only its own kind.
    @Test func testTypeGroupsByEntryType() {
        let entries: [any Entry] = [
            DataModel.Task(title: "A Task", date: today),
            DataModel.Note(title: "A Note", date: today),
            DataModel.Event(title: "An Event", startDate: today, endDate: today)
        ]

        let result = sections(for: entries, option: .type)

        #expect(result.map(\.id).sorted() == ["Event", "Note", "Task"])
        #expect(result.first { $0.id == "Task" }?.entries.map(\.title) == ["A Task"])
        #expect(result.first { $0.id == "Note" }?.entries.map(\.title) == ["A Note"])
        #expect(result.first { $0.id == "Event" }?.entries.map(\.title) == ["An Event"])
    }
}
