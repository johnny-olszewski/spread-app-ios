import Foundation
import Testing
@testable import Spread

/// Tests for entry list grouping logic.
///
/// Day spread grouping is covered via `DaySpreadContentView.ViewModel.makeSections`, exercised
/// here with `.list`/`.dueDate` (the spread's default picker selection) to prove parity with the
/// pre-SPRD-259 hand-rolled behavior these tests originally covered. The "Untitled" bucket name
/// (was "No List") is a deliberate, documented SPRD-259 change — see `EntryGroupingOption`.
/// Multiday spread grouping is covered via `MultidaySpreadContentView.ViewModel.makeSections`.
@Suite("Entry List Grouping Tests")
@MainActor
struct EntryListGroupingTests {

    // MARK: - Test Calendar Setup

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Day Spread Grouping Tests

    /// When a day spread has tasks assigned to named lists and tasks with no list,
    /// named-list sections appear first (alphabetical) and the unlisted section appears last.
    @Test("Day spread groups by named list with unlisted entries at end")
    func daySpreadGroupsByList() {
        let spreadDate = makeDate(year: 2026, month: 4, day: 15)
        let listA = DataModel.List(name: "Alpha")
        let listB = DataModel.List(name: "Beta")

        let taskA1 = DataModel.Task(title: "Alpha Task 1", date: spreadDate, list: listA)
        let taskB1 = DataModel.Task(title: "Beta Task", date: spreadDate, list: listB)
        let taskNone = DataModel.Task(title: "No list", date: spreadDate)
        let note = DataModel.Note(title: "Note", date: spreadDate)

        let entries: [any Entry] = [taskNone, taskB1, taskA1, note]
        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 3)
        #expect(sections[0].title == "Alpha")
        #expect(sections[0].entries.map(\.title) == ["Alpha Task 1"])
        #expect(sections[1].title == "Beta")
        #expect(sections[1].entries.map(\.title) == ["Beta Task"])
        #expect(sections[2].title == "Untitled")
        let unlisted = sections[2].entries.map(\.title)
        #expect(unlisted.contains("No list"))
        #expect(unlisted.contains("Note"))
    }

    /// When a day spread has entries but no list assignments,
    /// a single untitled section is produced.
    @Test("Day spread with no list assignments produces one unlisted section")
    func daySpreadWithNoListsProducesOneSection() {
        let spreadDate = makeDate(year: 2026, month: 4, day: 15)
        // Events are separated into their own section; use only tasks and notes to test unlisted grouping.
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: spreadDate),
            DataModel.Task(title: "Task 2", date: spreadDate),
            DataModel.Note(title: "Note 1", date: spreadDate)
        ]

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 1)
        #expect(sections[0].title == "Untitled")
        #expect(sections[0].entries.count == 3)
    }

    /// When a day spread has a task assigned to a named list,
    /// that task goes into its list's section and unlisted entries go into an untitled section.
    @Test("Day spread always groups by list — listed task appears in its list section")
    func daySpreadListAssignedTaskGroupedWithList() {
        let spreadDate = makeDate(year: 2026, month: 6, day: 1)
        let list = DataModel.List(name: "Work")
        let entries: [any Entry] = [
            DataModel.Task(title: "Listed task", date: spreadDate, list: list),
            DataModel.Task(title: "Unlisted task", date: spreadDate),
            DataModel.Note(title: "Note", date: spreadDate)
        ]

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 2)
        #expect(sections[0].title == "Work")
        #expect(sections[0].entries.map(\.title) == ["Listed task"])
        #expect(sections[1].title == "Untitled")
        #expect(sections[1].entries.count == 2)
    }

    /// When a day spread has a single entry,
    /// it should be in a single flat section.
    @Test("Day spread with single entry creates one section")
    func daySpreadSingleEntryOneSection() {
        let spreadDate = makeDate(year: 2026, month: 6, day: 1)
        let entries: [any Entry] = [
            DataModel.Task(title: "Solo Task", date: spreadDate)
        ]

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 1)
        #expect(sections[0].entries.count == 1)
    }

    /// When no entries are provided, the result is empty.
    @Test("Day spread empty entries returns empty sections")
    func daySpreadEmptyEntriesReturnsEmpty() {
        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: [],
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )
        #expect(sections.isEmpty)
    }

    /// When entries within a day section have different dates,
    /// they should be sorted chronologically.
    @Test("Day spread entries sorted chronologically within section")
    func daySpreadEntriesSortedChronologically() {
        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 3", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 5)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 10))
        ]

        let sections = DaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: spreadDate,
            groupingOption: .list,
            sortingOption: .dueDate,
            eventConfigurationMap: [:]
        )

        #expect(sections.count == 1)
        #expect(sections[0].entries.map(\.title) == ["Task 1", "Task 2", "Task 3"])
    }

    // MARK: - Multiday Spread Grouping Tests

    /// When a multiday spread contains entries from different days within the range,
    /// the grouper should create separate sections for each day in chronological order.
    @Test("Multiday spread groups entries by day within range")
    func multidaySpreadGroupsByDayWithinRange() {
        let startDate = makeDate(year: 2026, month: 1, day: 5)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let entries: [any Entry] = [
            DataModel.Task(title: "Day 6 Task", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 8 Task", date: makeDate(year: 2026, month: 1, day: 8)),
            DataModel.Event(title: "Day 7 Event", startDate: makeDate(year: 2026, month: 1, day: 7)),
            DataModel.Note(title: "Day 6 Note", date: makeDate(year: 2026, month: 1, day: 6))
        ]

        let sections = MultidaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: startDate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        #expect(sections.count == 4)
        #expect(sections[0].entries.isEmpty)
        #expect(sections[1].entries.count == 2)
        #expect(sections[2].entries.count == 1)
        #expect(sections[3].entries.count == 1)
    }

    /// When a multiday spread has no entries on some covered days,
    /// the grouper should still return empty sections for those dates.
    @Test("Multiday spread includes empty sections for uncovered days")
    func multidaySpreadIncludesEmptyDays() {
        let startDate = makeDate(year: 2026, month: 1, day: 10)
        let endDate = makeDate(year: 2026, month: 1, day: 12)
        let entries: [any Entry] = [
            DataModel.Task(title: "Middle Task", date: makeDate(year: 2026, month: 1, day: 11))
        ]

        let sections = MultidaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: startDate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        #expect(sections.count == 3)
        #expect(sections[0].entries.isEmpty)
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].entries.isEmpty)
    }

    /// When a multiday spread contains a month-assigned task dated within the range,
    /// the task should not appear in that day's section.
    @Test("Multiday spread excludes month-assigned tasks from day sections")
    func multidaySpreadExcludesMonthAssignedTasks() {
        let startDate = makeDate(year: 2026, month: 3, day: 30)
        let endDate = makeDate(year: 2026, month: 4, day: 5)
        let entries: [any Entry] = [
            DataModel.Task(title: "April Month Task", date: makeDate(year: 2026, month: 4, day: 1), period: .month),
            DataModel.Task(title: "April 1 Day Task", date: makeDate(year: 2026, month: 4, day: 1), period: .day)
        ]

        let sections = MultidaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: startDate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        let aprilFirst = makeDate(year: 2026, month: 4, day: 1)
        let aprilFirstSection = sections.first { calendar.isDate($0.date, inSameDayAs: aprilFirst) }

        #expect(aprilFirstSection != nil)
        #expect(aprilFirstSection?.entries.map(\.title) == ["April 1 Day Task"])
    }

    /// When a multiday spread contains entries from different days,
    /// each day always gets its own section — entries from different days never merge.
    @Test("Multiday spread always groups by day — entries from different days in separate sections")
    func multidaySpreadEntriesFromDifferentDaysAppearInSeparateSections() {
        let startDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let entries: [any Entry] = [
            DataModel.Task(title: "Day 6 task", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 8 task", date: makeDate(year: 2026, month: 1, day: 8))
        ]

        let sections = MultidaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: startDate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        #expect(sections.count == 3)
        #expect(sections[0].entries.count == 1) // Jan 6
        #expect(sections[0].entries.map(\.title) == ["Day 6 task"])
        #expect(sections[1].entries.isEmpty)    // Jan 7 — no entries
        #expect(sections[2].entries.count == 1) // Jan 8
        #expect(sections[2].entries.map(\.title) == ["Day 8 task"])
    }

    /// Multiday-assigned entries appear in the "This Range" section above day sections.
    @Test("Multiday-assigned entries appear in the leading This Range section")
    func multidayAssignedEntriesAppearInRangeSection() {
        let startDate = makeDate(year: 2026, month: 1, day: 6)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let entries: [any Entry] = [
            DataModel.Task(title: "Range task", date: startDate, period: .multiday),
            DataModel.Task(title: "Day task", date: makeDate(year: 2026, month: 1, day: 7), period: .day)
        ]

        let sections = MultidaySpreadContentView.ViewModel.makeSections(
            from: entries,
            spreadDate: startDate,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        let rangeSection = sections.first { $0.creationPeriod == .multiday }
        #expect(rangeSection != nil)
        #expect(rangeSection?.title == "This Range")
        #expect(rangeSection?.entries.map(\.title) == ["Range task"])
    }
}
