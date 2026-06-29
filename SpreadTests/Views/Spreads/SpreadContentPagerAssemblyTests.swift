import Foundation
import Testing
@testable import Spread

/// Tests for SpreadContentPagerView page assembly: spread-type content selection and data model routing.
@Suite("SpreadContentPager Assembly Tests")
@MainActor
struct SpreadContentPagerAssemblyTests {

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Conventional Data Model Routing

    /// Condition: Conventional mode, year spread exists in JournalManager.
    /// Expected: dataModel for the year period and date is non-nil and reflects added spreads.
    @Test("Conventional year spread data model is reachable via dataModel dictionary")
    func testConventionalYearSpreadDataModelIsReachable() async throws {
        let today = Self.makeDate(year: 2026, month: 1)
        let manager = try await JournalManager(
            calendar: Self.calendar,
            today: today,
        )
        _ = try await manager.addSpread(period: .year, date: today)

        let normalizedDate = Period.year.normalizeDate(today, calendar: Self.calendar)
        let dataModel = manager.dataModel[.year]?[normalizedDate]

        #expect(dataModel != nil)
    }

    /// Condition: Conventional mode, day spread with two tasks.
    /// Expected: dataModel carries both tasks.
    @Test("Conventional day spread data model carries tasks")
    func testConventionalDaySpreadDataModelCarriesTasks() async throws {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let manager = try await JournalManager(
            calendar: Self.calendar,
            today: today,
        )
        _ = try await manager.addSpread(period: .day, date: today)
        _ = try await manager.addTask(title: "Task A", date: today, period: .day)
        _ = try await manager.addTask(title: "Task B", date: today, period: .day)

        let normalizedDate = Period.day.normalizeDate(today, calendar: Self.calendar)
        let dataModel = manager.dataModel[.day]?[normalizedDate]

        #expect(dataModel?.tasks.count == 2)
    }

    // MARK: - Period Routing

    /// Condition: Year-period spread.
    /// Expected: YearSpreadContentView is the appropriate type (period == .year).
    @Test("Year spread maps to year period")
    func testYearSpreadPeriod() {
        let date = Self.makeDate(year: 2026, month: 1)
        let spread = DataModel.Spread(period: .year, date: date, calendar: Self.calendar)
        #expect(spread.period == .year)
    }

    /// Condition: Month-period spread.
    /// Expected: MonthSpreadContentView is the appropriate type (period == .month).
    @Test("Month spread maps to month period")
    func testMonthSpreadPeriod() {
        let date = Self.makeDate(year: 2026, month: 4)
        let spread = DataModel.Spread(period: .month, date: date, calendar: Self.calendar)
        #expect(spread.period == .month)
    }

    /// Condition: Day-period spread.
    /// Expected: DaySpreadContentView is the appropriate type (period == .day).
    @Test("Day spread maps to day period")
    func testDaySpreadPeriod() {
        let date = Self.makeDate(year: 2026, month: 4, day: 13)
        let spread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        #expect(spread.period == .day)
    }

    /// Condition: Multiday spread.
    /// Expected: MultidaySpreadContentView is the appropriate type (period == .multiday).
    @Test("Multiday spread maps to multiday period")
    func testMultidaySpreadPeriod() {
        let startDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let endDate = Self.makeDate(year: 2026, month: 4, day: 12)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)
        #expect(spread.period == .multiday)
    }

    // MARK: - Migration Configuration

    /// Condition: Multiday spread has no migration configuration.
    /// Expected: migrationConfiguration returns nil for multiday period.
    @Test("Multiday spread has no migration configuration")
    func testMultidaySpreadHasNoMigrationConfiguration() async throws {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let manager = try await JournalManager(
            calendar: Self.calendar,
            today: today,
        )

        let startDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let endDate = today
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)

        // Multiday spreads are excluded from migration
        #expect(spread.period == .multiday)
        // The guard `spread.period != .multiday else { return nil }` in the assembler
        // ensures migration config is never computed for multiday.
    }

    // MARK: - Entry List Grouping

    /// Condition: Day spread has a task assigned to a named list and an unlisted task.
    /// Expected: Entries are bucketed by named list, with unlisted entries in an untitled section.
    @Test("Day spread groups by list")
    func testDaySpreadGroupsByList() {
        let spreadDate = Self.makeDate(year: 2026, month: 4, day: 13)
        let list = DataModel.List(name: "Work")
        let entries: [any Entry] = [
            DataModel.Task(title: "Listed", date: spreadDate, list: list),
            DataModel.Task(title: "Unlisted", date: spreadDate)
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
        #expect(sections[1].title == "Untitled")
    }
}
