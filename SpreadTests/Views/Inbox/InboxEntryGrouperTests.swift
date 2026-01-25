import Foundation
import Testing
@testable import Spread

/// Tests for InboxEntryGrouper.
///
/// Verifies that inbox entries are grouped correctly by type,
/// with tasks appearing before notes.
@Suite("Inbox Entry Grouper Tests")
struct InboxEntryGrouperTests {

    // MARK: - Test Helpers

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Grouping Order Tests

    /// When both tasks and notes exist,
    /// tasks should be grouped first, then notes.
    @Test("Tasks grouped before notes")
    func tasksGroupedBeforeNotes() {
        let entries: [any Entry] = [
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 10)),
            DataModel.Note(title: "Note 2", date: makeDate(year: 2026, month: 1, day: 20)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 5))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 2)
        #expect(sections[0].entryType == .task)
        #expect(sections[0].entries.count == 2)
        #expect(sections[1].entryType == .note)
        #expect(sections[1].entries.count == 2)
    }

    /// When only tasks exist,
    /// only a tasks section should be created.
    @Test("Tasks only creates single section")
    func tasksOnlyCreatesSingleSection() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 10)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 5))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].entryType == .task)
        #expect(sections[0].entries.count == 2)
    }

    /// When only notes exist,
    /// only a notes section should be created.
    @Test("Notes only creates single section")
    func notesOnlyCreatesSingleSection() {
        let entries: [any Entry] = [
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Note(title: "Note 2", date: makeDate(year: 2026, month: 1, day: 20))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].entryType == .note)
        #expect(sections[0].entries.count == 2)
    }

    // MARK: - Empty State Tests

    /// When no entries exist,
    /// no sections should be created.
    @Test("Empty entries returns empty sections")
    func emptyEntriesReturnsEmptySections() {
        let entries: [any Entry] = []

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.isEmpty)
    }

    // MARK: - Chronological Order Tests

    /// When entries are in the same group,
    /// they should be sorted by date (earliest first).
    @Test("Entries within section sorted by date")
    func entriesWithinSectionSortedByDate() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task C", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Task(title: "Task A", date: makeDate(year: 2026, month: 1, day: 5)),
            DataModel.Task(title: "Task B", date: makeDate(year: 2026, month: 1, day: 10))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        let titles = sections[0].entries.map(\.title)
        #expect(titles == ["Task A", "Task B", "Task C"])
    }

    // MARK: - Section Title Tests

    /// When a section is for tasks,
    /// the title should be "Tasks".
    @Test("Tasks section has correct title")
    func tasksSectionHasCorrectTitle() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 10))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections[0].title == "Tasks")
    }

    /// When a section is for notes,
    /// the title should be "Notes".
    @Test("Notes section has correct title")
    func notesSectionHasCorrectTitle() {
        let entries: [any Entry] = [
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 1, day: 15))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections[0].title == "Notes")
    }

    // MARK: - Section Count Tests

    /// When section has tasks,
    /// the count should match the number of tasks.
    @Test("Section count matches entries")
    func sectionCountMatchesEntries() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 10)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 5)),
            DataModel.Task(title: "Task 3", date: makeDate(year: 2026, month: 1, day: 15))
        ]

        let grouper = InboxEntryGrouper(calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections[0].count == 3)
    }
}
