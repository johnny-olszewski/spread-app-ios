import Foundation
import Testing
@testable import Spread

/// Tests for entry list grouping logic across spread periods.
///
/// Verifies that entries are grouped correctly based on the spread period:
/// - Year: Groups by month
/// - Month: Groups by day
/// - Day: Flat list (single group)
/// - Multiday: Groups by day within range
@Suite("Entry List Grouping Tests")
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

    // MARK: - Year Spread Grouping Tests

    /// When a year spread contains entries from different months,
    /// the grouper should create separate sections for each month in chronological order.
    @Test("Year spread groups entries by month")
    func yearSpreadGroupsByMonth() {
        let entries: [any Entry] = [
            DataModel.Task(title: "January Task", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Task(title: "March Task", date: makeDate(year: 2026, month: 3, day: 10)),
            DataModel.Task(title: "January Task 2", date: makeDate(year: 2026, month: 1, day: 20)),
            DataModel.Event(title: "February Event", startDate: makeDate(year: 2026, month: 2, day: 5))
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].title == "January 2026")
        #expect(sections[0].entries.count == 2)
        #expect(sections[1].title == "February 2026")
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].title == "March 2026")
        #expect(sections[2].entries.count == 1)
    }

    /// When a year spread has entries all in the same month,
    /// only one section should be created.
    @Test("Year spread with single month creates one section")
    func yearSpreadSingleMonthOneSection() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 5, day: 1)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 5, day: 15)),
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 5, day: 20))
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title == "May 2026")
        #expect(sections[0].entries.count == 3)
    }

    // MARK: - Month Spread Grouping Tests

    /// When a month spread contains entries from different days,
    /// the grouper should create separate sections for each day in chronological order.
    @Test("Month spread groups entries by day")
    func monthSpreadGroupsByDay() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Day 5 Task", date: makeDate(year: 2026, month: 3, day: 5)),
            DataModel.Task(title: "Day 10 Task", date: makeDate(year: 2026, month: 3, day: 10)),
            DataModel.Task(title: "Day 5 Task 2", date: makeDate(year: 2026, month: 3, day: 5)),
            DataModel.Event(title: "Day 15 Event", startDate: makeDate(year: 2026, month: 3, day: 15))
        ]

        let spreadDate = makeDate(year: 2026, month: 3, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].title == "March 5")
        #expect(sections[0].entries.count == 2)
        #expect(sections[1].title == "March 10")
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].title == "March 15")
        #expect(sections[2].entries.count == 1)
    }

    /// When a month spread has entries all on the same day,
    /// only one section should be created.
    @Test("Month spread with single day creates one section")
    func monthSpreadSingleDayOneSection() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 7, day: 20)),
            DataModel.Event(title: "Event 1", startDate: makeDate(year: 2026, month: 7, day: 20))
        ]

        let spreadDate = makeDate(year: 2026, month: 7, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title == "July 20")
        #expect(sections[0].entries.count == 2)
    }

    // MARK: - Day Spread Grouping Tests

    /// When a day spread contains entries,
    /// they should all be in a single flat section (no grouping).
    @Test("Day spread creates flat list with no grouping")
    func daySpreadCreatesFlastList() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 4, day: 15)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 4, day: 15)),
            DataModel.Event(title: "Event 1", startDate: makeDate(year: 2026, month: 4, day: 15)),
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 4, day: 15))
        ]

        let spreadDate = makeDate(year: 2026, month: 4, day: 15)
        let grouper = EntryListGrouper(period: .day, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.count == 4)
    }

    /// When a day spread has a single entry,
    /// it should be in a single flat section.
    @Test("Day spread with single entry creates one section")
    func daySpreadSingleEntryOneSection() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Solo Task", date: makeDate(year: 2026, month: 6, day: 1))
        ]

        let spreadDate = makeDate(year: 2026, month: 6, day: 1)
        let grouper = EntryListGrouper(period: .day, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].entries.count == 1)
    }

    // MARK: - Multiday Spread Grouping Tests

    /// When a multiday spread contains entries from different days within the range,
    /// the grouper should create separate sections for each day in chronological order.
    @Test("Multiday spread groups entries by day within range")
    func multidaySpreadGroupsByDayWithinRange() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Day 6 Task", date: makeDate(year: 2026, month: 1, day: 6)),
            DataModel.Task(title: "Day 8 Task", date: makeDate(year: 2026, month: 1, day: 8)),
            DataModel.Event(title: "Day 7 Event", startDate: makeDate(year: 2026, month: 1, day: 7)),
            DataModel.Note(title: "Day 6 Note", date: makeDate(year: 2026, month: 1, day: 6))
        ]

        // Multiday spread for Jan 5-12, 2026 (a week)
        let spreadDate = makeDate(year: 2026, month: 1, day: 5)
        let grouper = EntryListGrouper(period: .multiday, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].title == "January 6")
        #expect(sections[0].entries.count == 2)
        #expect(sections[1].title == "January 7")
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].title == "January 8")
        #expect(sections[2].entries.count == 1)
    }

    // MARK: - Empty State Tests

    /// When no entries are provided,
    /// the grouper should return an empty array.
    @Test("Empty entries returns empty sections")
    func emptyEntriesReturnsEmptySections() {
        let entries: [any Entry] = []

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.isEmpty)
    }

    // MARK: - Mixed Entry Type Tests

    /// When entries include tasks, events, and notes,
    /// all should be included in the appropriate sections.
    @Test("All entry types included in sections")
    func allEntryTypesIncludedInSections() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task", date: makeDate(year: 2026, month: 2, day: 10)),
            DataModel.Event(title: "Event", startDate: makeDate(year: 2026, month: 2, day: 10)),
            DataModel.Note(title: "Note", date: makeDate(year: 2026, month: 2, day: 10))
        ]

        let spreadDate = makeDate(year: 2026, month: 2, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].entries.count == 3)

        // Verify all types are present
        let entryTypes = sections[0].entries.map(\.entryType)
        #expect(entryTypes.contains(.task))
        #expect(entryTypes.contains(.event))
        #expect(entryTypes.contains(.note))
    }

    // MARK: - Chronological Order Tests

    /// When entries within a section have different dates,
    /// they should be sorted chronologically within the section.
    @Test("Entries within section sorted chronologically")
    func entriesWithinSectionSortedChronologically() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 3", date: makeDate(year: 2026, month: 1, day: 15)),
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 1, day: 5)),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 1, day: 10))
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        let titles = sections[0].entries.map(\.title)
        #expect(titles == ["Task 1", "Task 2", "Task 3"])
    }

    // MARK: - Section Date Tests

    /// When grouping by month for a year spread,
    /// the section should include the date for identification purposes.
    @Test("Year spread sections include date for month")
    func yearSpreadSectionsIncludeDate() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task", date: makeDate(year: 2026, month: 3, day: 15))
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        // Section date should be the first day of the month
        let expectedDate = makeDate(year: 2026, month: 3, day: 1)
        #expect(calendar.isDate(sections[0].date, inSameDayAs: expectedDate))
    }

    /// When grouping by day for a month spread,
    /// the section should include the exact date.
    @Test("Month spread sections include exact date")
    func monthSpreadSectionsIncludeExactDate() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task", date: makeDate(year: 2026, month: 5, day: 20))
        ]

        let spreadDate = makeDate(year: 2026, month: 5, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        let expectedDate = makeDate(year: 2026, month: 5, day: 20)
        #expect(calendar.isDate(sections[0].date, inSameDayAs: expectedDate))
    }
}
