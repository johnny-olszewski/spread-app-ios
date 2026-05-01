import Foundation
import Testing
@testable import Spread

@MainActor
@Suite("MonthSpreadContentSupportTests")
struct MonthSpreadContentSupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Month content should split month-period entries from day-period sections.
    /// Setup: a month spread contains one month task plus day task/note entries on two dates.
    /// Expected: the month section contains only the month task and the day sections are keyed by day date.
    @Test("Model separates month entries from day sections")
    func modelSeparatesMonthEntriesFromDaySections() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)

        var spreadDataModel = SpreadDataModel(spread: monthSpread)
        spreadDataModel.tasks = [
            DataModel.Task(title: "Month Task", date: monthDate, period: .month),
            DataModel.Task(title: "Day Task", date: Self.makeDate(year: 2026, month: 1, day: 5), period: .day)
        ]
        spreadDataModel.notes = [
            DataModel.Note(title: "Day Note", date: Self.makeDate(year: 2026, month: 1, day: 10), period: .day)
        ]

        let model = MonthSpreadContentSupport.model(
            for: monthSpread,
            spreadDataModel: spreadDataModel,
            spreads: [],
            calendar: Self.calendar
        )

        #expect(model.monthEntries.map(\.title) == ["Month Task"])
        #expect(model.daySections.map(\.entries).map { $0.map(\.title) } == [["Day Task"], ["Day Note"]])
        #expect(model.daySections.map(\.action) == [nil, nil])
    }

    /// Explicit empty day spreads should still appear in the day-section list.
    /// Setup: a month spread has no day entries, but Jan 12 has an explicit day spread.
    /// Expected: Jan 12 renders as an empty section with a view action.
    @Test("Explicit empty day spread still renders its section")
    func explicitEmptyDaySpreadStillRendersSection() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let daySpreadDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: daySpreadDate, calendar: Self.calendar)

        let model = MonthSpreadContentSupport.model(
            for: monthSpread,
            spreadDataModel: SpreadDataModel(spread: monthSpread),
            spreads: [daySpread],
            calendar: Self.calendar
        )

        #expect(model.daySections.count == 1)
        #expect(model.daySections[0].date == daySpreadDate)
        #expect(model.daySections[0].entries.isEmpty)
        #expect(model.daySections[0].action == .view(daySpread))
    }

    /// Day-section navigation should only exist when an explicit day spread exists.
    /// Setup: one date has only month-hosted day content and another has an explicit day spread.
    /// Expected: only the explicit day spread section exposes a navigation action.
    @Test("Day section navigation only exists for explicit day spreads")
    func daySectionNavigationOnlyExistsForExplicitDaySpreads() {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let explicitDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let explicitDaySpread = DataModel.Spread(period: .day, date: explicitDate, calendar: Self.calendar)

        var spreadDataModel = SpreadDataModel(spread: monthSpread)
        spreadDataModel.tasks = [DataModel.Task(title: "Fallback Day Task", date: Self.makeDate(year: 2026, month: 1, day: 6), period: .day)]

        let model = MonthSpreadContentSupport.model(
            for: monthSpread,
            spreadDataModel: spreadDataModel,
            spreads: [explicitDaySpread],
            calendar: Self.calendar
        )

        #expect(model.daySections.count == 2)
        #expect(model.daySections[0].action == nil)
        #expect(model.daySections[1].action == .view(explicitDaySpread))
    }

    /// Migrated source-history rows should not stay visible on the month spread once a more granular day spread owns them.
    /// Setup: a month task remains open on the month spread while a day task has a migrated month assignment and an open day assignment.
    /// Expected: the month content keeps only the month task, and the explicit day section stays present but empty on the month surface.
    @Test("Current-assignment-only month content excludes migrated source rows")
    func currentAssignmentOnlyMonthContentExcludesMigratedSourceRows() async throws {
        let monthDate = Self.makeDate(year: 2026, month: 1)
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)

        let currentMonthTask = DataModel.Task(
            title: "Current Month Task",
            date: monthDate,
            period: .month,
            assignments: [TaskAssignment(period: .month, date: monthDate, status: .open)]
        )
        let migratedAwayTask = DataModel.Task(
            title: "Migrated Away",
            date: dayDate,
            period: .day,
            assignments: [
                TaskAssignment(period: .month, date: monthDate, status: .migrated),
                TaskAssignment(period: .day, date: dayDate, status: .open)
            ]
        )

        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: dayDate,
            taskRepository: InMemoryTaskRepository(tasks: [currentMonthTask, migratedAwayTask]),
            spreadRepository: InMemorySpreadRepository(spreads: [monthSpread, daySpread]),
            bujoMode: .conventional
        )

        let monthDataModel = try #require(
            manager.dataModel[.month]?[Period.month.normalizeDate(monthDate, calendar: Self.calendar)]
        )
        let model = MonthSpreadContentSupport.model(
            for: monthSpread,
            spreadDataModel: monthDataModel,
            spreads: manager.spreads,
            calendar: Self.calendar
        )

        #expect(model.monthEntries.map(\.title) == ["Current Month Task"])
        #expect(model.daySections.count == 1)
        #expect(model.daySections[0].entries.isEmpty)
        #expect(model.daySections[0].action == .view(daySpread))
    }
}
