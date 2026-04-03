import Foundation
import Testing
@testable import Spread

/// Tests for entry list grouping logic across spread periods.
///
/// Verifies that entries are grouped correctly based on the spread period:
/// - Year: Untitled current-year tasks, then month sections with month/day tasks
/// - Month: Untitled current-month list with day-number context for day tasks
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

    /// When a year spread contains year-, month-, and day-assigned tasks,
    /// the grouper should keep year tasks untitled and place month/day tasks in month sections.
    @Test("Year spread keeps current-year tasks untitled and groups month/day tasks by month")
    func yearSpreadUsesUntitledYearSectionAndMonthSections() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Year Task", date: makeDate(year: 2026, month: 1, day: 1), period: .year),
            DataModel.Task(title: "January Month Task", date: makeDate(year: 2026, month: 1, day: 1), period: .month),
            DataModel.Task(title: "January Day Task", date: makeDate(year: 2026, month: 1, day: 20), period: .day),
            DataModel.Task(title: "March Day Task", date: makeDate(year: 2026, month: 3, day: 10), period: .day)
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.map(\.title) == ["Year Task"])
        #expect(sections[1].title == "January 2026")
        #expect(sections[1].entries.map(\.title) == ["January Month Task", "January Day Task"])
        #expect(sections[1].contextualLabels.count == 1)
        #expect(sections[1].contextualLabels[sections[1].entries[1].id] == "20")
        #expect(sections[2].title == "March 2026")
        #expect(sections[2].entries.count == 1)
        #expect(sections[2].contextualLabels[sections[2].entries[0].id] == "10")
    }

    /// When a year spread has no year-assigned tasks,
    /// it should not create an empty untitled section before the month sections.
    @Test("Year spread omits untitled section when no year tasks exist")
    func yearSpreadOmitsUntitledSectionWhenUnused() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 5, day: 1), period: .month),
            DataModel.Task(title: "Task 2", date: makeDate(year: 2026, month: 5, day: 15), period: .day),
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 5, day: 20), period: .day)
        ]

        let spreadDate = makeDate(year: 2026, month: 1, day: 1)
        let grouper = EntryListGrouper(period: .year, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title == "May 2026")
        #expect(sections[0].entries.count == 3)
        #expect(sections[0].contextualLabels.count == 2)
    }

    // MARK: - Month Spread Grouping Tests

    /// When a month spread contains month-, year-, and day-assigned entries,
    /// the grouper should keep them in one untitled section and label only day entries.
    @Test("Month spread keeps tasks in one untitled list and labels day tasks")
    func monthSpreadUsesSingleUntitledSectionWithDayLabels() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Inherited Year Task", date: makeDate(year: 2026, month: 1, day: 1), period: .year),
            DataModel.Task(title: "Month Task", date: makeDate(year: 2026, month: 3, day: 1), period: .month),
            DataModel.Task(title: "Day 5 Task", date: makeDate(year: 2026, month: 3, day: 5), period: .day),
            DataModel.Note(title: "Day 10 Note", date: makeDate(year: 2026, month: 3, day: 10), period: .day)
        ]

        let spreadDate = makeDate(year: 2026, month: 3, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.map(\.title) == [
            "Inherited Year Task",
            "Month Task",
            "Day 5 Task",
            "Day 10 Note",
        ])
        #expect(sections[0].contextualLabels.count == 2)
        #expect(sections[0].contextualLabels[sections[0].entries[2].id] == "5")
        #expect(sections[0].contextualLabels[sections[0].entries[3].id] == "10")
    }

    /// When a month spread has only month-assigned entries,
    /// it should still render a single untitled section with no day labels.
    @Test("Month spread with only month entries has no contextual day labels")
    func monthSpreadWithOnlyMonthEntriesHasNoDayLabels() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task 1", date: makeDate(year: 2026, month: 7, day: 1), period: .month),
            DataModel.Note(title: "Note 1", date: makeDate(year: 2026, month: 7, day: 1), period: .month)
        ]

        let spreadDate = makeDate(year: 2026, month: 7, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        #expect(sections[0].title.isEmpty)
        #expect(sections[0].entries.count == 2)
        #expect(sections[0].contextualLabels.isEmpty)
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

        // Multiday spread for Jan 5-8, 2026.
        let startDate = makeDate(year: 2026, month: 1, day: 5)
        let endDate = makeDate(year: 2026, month: 1, day: 8)
        let grouper = EntryListGrouper(
            period: .multiday,
            spreadDate: startDate,
            spreadStartDate: startDate,
            spreadEndDate: endDate,
            calendar: calendar
        )
        let sections = grouper.group(entries)

        #expect(sections.count == 4)
        #expect(sections[0].title == "January 5")
        #expect(sections[0].entries.isEmpty)
        #expect(sections[1].title == "January 6")
        #expect(sections[1].entries.count == 2)
        #expect(sections[2].title == "January 7")
        #expect(sections[2].entries.count == 1)
        #expect(sections[3].title == "January 8")
        #expect(sections[3].entries.count == 1)
    }

    /// When a multiday spread has no entries on some covered days,
    /// the grouper should still return empty sections for those dates.
    @Test("Multiday spread includes empty sections for uncovered days")
    func multidaySpreadIncludesEmptyDays() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Middle Task", date: makeDate(year: 2026, month: 1, day: 11))
        ]

        let startDate = makeDate(year: 2026, month: 1, day: 10)
        let endDate = makeDate(year: 2026, month: 1, day: 12)
        let grouper = EntryListGrouper(
            period: .multiday,
            spreadDate: startDate,
            spreadStartDate: startDate,
            spreadEndDate: endDate,
            calendar: calendar
        )
        let sections = grouper.group(entries)

        #expect(sections.count == 3)
        #expect(sections[0].entries.isEmpty)
        #expect(sections[1].entries.count == 1)
        #expect(sections[2].entries.isEmpty)
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

    /// When grouping a month spread,
    /// the section date should remain the month spread date because the list is unsectioned.
    @Test("Month spread section keeps month spread date")
    func monthSpreadSectionsKeepMonthSpreadDate() {
        let entries: [any Entry] = [
            DataModel.Task(title: "Task", date: makeDate(year: 2026, month: 5, day: 20), period: .day)
        ]

        let spreadDate = makeDate(year: 2026, month: 5, day: 1)
        let grouper = EntryListGrouper(period: .month, spreadDate: spreadDate, calendar: calendar)
        let sections = grouper.group(entries)

        #expect(sections.count == 1)
        let expectedDate = makeDate(year: 2026, month: 5, day: 1)
        #expect(calendar.isDate(sections[0].date, inSameDayAs: expectedDate))
    }
}
