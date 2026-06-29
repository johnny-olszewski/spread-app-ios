import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct OverdueCardViewTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    @MainActor
    private static func makeContext(
        today: Date,
        tasks: [DataModel.Task] = [],
        spreads: [DataModel.Spread] = []
    ) async throws -> SpreadPageContext {
        let manager = try await JournalManager(
            calendar: testCalendar,
            today: today,
            taskRepository: TestTaskRepository(tasks: tasks),
            spreadRepository: TestSpreadRepository(spreads: spreads)
        )
        return SpreadPageContext(
            journalManager: manager,
            coordinator: SpreadsCoordinator(),
            syncEngine: nil,
            eventKitService: nil,
            calendarEventService: MockCalendarEventService()
        )
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        testCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Day

    /// Setup: a day spread whose date matches today, with one overdue task.
    /// Expected: one "Overdue" section is produced.
    @MainActor @Test func daySpreadMatchingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)

        let sections = OverdueCardView.sections(for: spread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a day spread whose date does NOT match today.
    /// Expected: no sections, even though there is an overdue task elsewhere in the journal.
    @MainActor @Test func daySpreadNotMatchingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 1, 12)
        let overdueDate = Self.date(2026, 1, 10)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let otherDaySpread = DataModel.Spread(period: .day, date: overdueDate, calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherDaySpread, context: context).isEmpty)
    }

    // MARK: - Month

    /// Setup: a month spread for the same month as today, with an overdue task assigned to an
    /// earlier month.
    /// Expected: the overdue section is shown, since the displayed month contains today.
    @MainActor @Test func monthSpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 2, 15)
        let overdueMonth = Self.date(2026, 1, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueMonth,
            period: .month,
            status: .open,
            currentAssignments: [Assignment(period: .month, date: overdueMonth, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let thisMonthSpread = DataModel.Spread(period: .month, date: today, calendar: Self.testCalendar)

        let sections = OverdueCardView.sections(for: thisMonthSpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a month spread for a month other than today's.
    /// Expected: no sections.
    @MainActor @Test func monthSpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 2, 15)
        let context = try await Self.makeContext(today: today)
        let otherMonthSpread = DataModel.Spread(period: .month, date: Self.date(2026, 1, 1), calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherMonthSpread, context: context).isEmpty)
    }

    // MARK: - Year

    /// Setup: a year spread for the same year as today.
    /// Expected: the overdue section is shown.
    @MainActor @Test func yearSpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2027, 1, 1)
        let lastYear = Self.date(2025, 1, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: lastYear,
            period: .year,
            status: .open,
            currentAssignments: [Assignment(period: .year, date: lastYear, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let thisYearSpread = DataModel.Spread(period: .year, date: today, calendar: Self.testCalendar)

        let sections = OverdueCardView.sections(for: thisYearSpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a year spread for a year other than today's.
    /// Expected: no sections.
    @MainActor @Test func yearSpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2027, 1, 1)
        let context = try await Self.makeContext(today: today)
        let otherYearSpread = DataModel.Spread(period: .year, date: Self.date(2025, 1, 1), calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: otherYearSpread, context: context).isEmpty)
    }

    // MARK: - Multiday

    /// Setup: a multiday spread whose range contains today (today falls strictly inside the range).
    /// Expected: the overdue section is shown.
    @MainActor @Test func multidaySpreadContainingTodayShowsOverdueSection() async throws {
        let today = Self.date(2026, 6, 3)
        let overdueDate = Self.date(2026, 5, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )
        let context = try await Self.makeContext(today: today, tasks: [task])
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )

        let sections = OverdueCardView.sections(for: multidaySpread, context: context)

        #expect(sections.count == 1)
        #expect(sections.first?.entries.map(\.id) == [task.id])
    }

    /// Setup: a multiday spread where today falls exactly on the range's start/end boundary.
    /// Expected: the overdue section is shown for both boundary dates (inclusive range).
    @MainActor @Test func multidaySpreadBoundaryDatesAreInclusive() async throws {
        let startBoundaryToday = Self.date(2026, 6, 1)
        let endBoundaryToday = Self.date(2026, 6, 7)
        let overdueDate = Self.date(2026, 5, 1)
        let task = DataModel.Task(
            title: "Overdue",
            date: overdueDate,
            period: .day,
            status: .open,
            currentAssignments: [Assignment(period: .day, date: overdueDate, status: .open)]
        )

        let startContext = try await Self.makeContext(today: startBoundaryToday, tasks: [task])
        let endContext = try await Self.makeContext(today: endBoundaryToday, tasks: [task])
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )

        #expect(!OverdueCardView.sections(for: multidaySpread, context: startContext).isEmpty)
        #expect(!OverdueCardView.sections(for: multidaySpread, context: endContext).isEmpty)
    }

    /// Setup: a multiday spread whose range does not contain today.
    /// Expected: no sections.
    @MainActor @Test func multidaySpreadNotContainingTodayShowsNoSection() async throws {
        let today = Self.date(2026, 8, 1)
        let context = try await Self.makeContext(today: today)
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(2026, 6, 1),
            endDate: Self.date(2026, 6, 7),
            calendar: Self.testCalendar
        )

        #expect(OverdueCardView.sections(for: multidaySpread, context: context).isEmpty)
    }

    // MARK: - Empty overdue items

    /// Setup: a day spread matching today, but there are no overdue tasks anywhere in the journal.
    /// Expected: no sections, even though the spread represents today.
    @MainActor @Test func noOverdueItemsShowsNoSectionEvenWhenSpreadRepresentsToday() async throws {
        let today = Self.date(2026, 1, 12)
        let context = try await Self.makeContext(today: today)
        let spread = DataModel.Spread(period: .day, date: today, calendar: Self.testCalendar)

        #expect(OverdueCardView.sections(for: spread, context: context).isEmpty)
    }
}
