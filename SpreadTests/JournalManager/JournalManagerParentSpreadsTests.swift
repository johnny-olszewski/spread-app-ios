import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct JournalManagerParentSpreadsTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Year period

    /// Conditions: Viewing a year spread. A July month spread exists for today (July 6, 2026).
    /// Expected: Returns [monthSpread] — year period now shows all other existing-period shortcuts.
    @Test @MainActor func yearPeriodReturnsOtherExistingPeriods() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread])
        )

        let context = manager.todayContextSpreads(for: .year)
        #expect(context.count == 1)
        #expect(context.first?.id == monthSpread.id)
    }

    /// Conditions: Viewing a year spread. No other period spreads exist.
    /// Expected: Returns [].
    @Test @MainActor func yearPeriodReturnsEmptyWhenNoOtherPeriodSpreadsExist() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [yearSpread])
        )

        let context = manager.todayContextSpreads(for: .year)
        #expect(context.isEmpty)
    }

    /// Conditions: Viewing a year spread. Both a day spread for today and a month spread exist.
    /// Expected: Returns [daySpread, monthSpread] — most-granular first.
    @Test @MainActor func yearPeriodReturnsSpreadsInGranularityOrder() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, monthSpread])
        )

        let context = manager.todayContextSpreads(for: .year)
        #expect(context.count == 2)
        #expect(context[0].id == daySpread.id)
        #expect(context[1].id == monthSpread.id)
    }

    // MARK: - Month period

    /// Conditions: Today is July 6, 2026. A year spread for 2026 exists. Viewing a month spread.
    /// Expected: Returns today's year spread (the "This Year" shortcut).
    @Test @MainActor func monthPeriodReturnsTodayYearSpread() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [yearSpread])
        )

        let context = manager.todayContextSpreads(for: .month)
        #expect(context.count == 1)
        #expect(context.first?.id == yearSpread.id)
        #expect(context.first?.period == .year)
    }

    /// Conditions: Today is July 6, 2026. Both a day spread and a year spread exist. Viewing a month spread.
    /// Expected: Returns [daySpread, yearSpread] in that order (most-granular first).
    @Test @MainActor func monthPeriodIncludesTodayDaySpreadBeforeYearSpread() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, yearSpread])
        )

        let context = manager.todayContextSpreads(for: .month)
        #expect(context.count == 2)
        #expect(context[0].id == daySpread.id)
        #expect(context[1].id == yearSpread.id)
    }

    /// Conditions: Today is July 6, 2026. No year or day spread exists. Viewing a month spread.
    /// Expected: Returns [] (no shortcuts when no other period spreads exist).
    @Test @MainActor func monthPeriodReturnsEmptyWhenNoOtherPeriodSpreadsExist() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread])
        )

        let context = manager.todayContextSpreads(for: .month)
        #expect(context.isEmpty)
    }

    // MARK: - Day period

    /// Conditions: Today is July 6, 2026. Both a July month spread and a 2026 year spread exist.
    /// Expected: Returns [monthSpread, yearSpread] in that order (most-granular first).
    @Test @MainActor func dayPeriodReturnsTodayMonthAndYearSpreads() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread, yearSpread])
        )

        let context = manager.todayContextSpreads(for: .day)
        #expect(context.count == 2)
        #expect(context[0].id == monthSpread.id)
        #expect(context[1].id == yearSpread.id)
    }

    /// Conditions: Today is July 6, 2026. Only a year spread exists (no month spread).
    /// Expected: Returns [yearSpread] only — the month shortcut is omitted when not created.
    @Test @MainActor func dayPeriodReturnsOnlyYearWhenNoMonthExists() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [yearSpread])
        )

        let context = manager.todayContextSpreads(for: .day)
        #expect(context.count == 1)
        #expect(context.first?.id == yearSpread.id)
    }

    /// Conditions: Today is July 6, 2026. No month or year spreads exist.
    /// Expected: Returns [].
    @Test @MainActor func dayPeriodReturnsEmptyWhenNoBroaderSpreadsExist() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [daySpread])
        )

        let context = manager.todayContextSpreads(for: .day)
        #expect(context.isEmpty)
    }

    /// Conditions: Today is July 6, 2026. A month spread for June (not today's month) and a year
    /// spread for 2026 exist.
    /// Expected: Only the year spread is returned — the June month spread doesn't contain today.
    @Test @MainActor func dayPeriodIgnoresMonthSpreadNotContainingToday() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let juneSpread = DataModel.Spread(period: .month, date: Self.date(year: 2026, month: 6), calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [juneSpread, yearSpread])
        )

        let context = manager.todayContextSpreads(for: .day)
        #expect(context.count == 1)
        #expect(context.first?.id == yearSpread.id)
    }

    // MARK: - Multiday period

    /// Conditions: Today is July 6, 2026. July month and 2026 year spreads exist. Viewing multiday.
    /// Expected: Returns [monthSpread, yearSpread] — multiday shows all other existing-period shortcuts.
    @Test @MainActor func multidayPeriodReturnsTodayMonthAndYearSpreads() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.date(year: 2026, month: 6, day: 28),
            endDate: Self.date(year: 2026, month: 7, day: 4),
            calendar: calendar
        )

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [multidaySpread, monthSpread, yearSpread])
        )

        let context = manager.todayContextSpreads(for: .multiday)
        #expect(context.count == 2)
        #expect(context[0].id == monthSpread.id)
        #expect(context[1].id == yearSpread.id)
    }

    /// Conditions: Today is July 6, 2026. Day, month, and year spreads all exist. Viewing multiday.
    /// Expected: Returns [daySpread, monthSpread, yearSpread] — most-granular first.
    @Test @MainActor func multidayPeriodIncludesTodayDaySpread() async throws {
        let calendar = Self.testCalendar
        let today = Self.date(year: 2026, month: 7, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            today: today,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, monthSpread, yearSpread])
        )

        let context = manager.todayContextSpreads(for: .multiday)
        #expect(context.count == 3)
        #expect(context[0].id == daySpread.id)
        #expect(context[1].id == monthSpread.id)
        #expect(context[2].id == yearSpread.id)
    }
}
