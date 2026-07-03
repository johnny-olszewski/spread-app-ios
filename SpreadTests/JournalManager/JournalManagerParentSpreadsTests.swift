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

    // MARK: - Year spread

    /// Conditions: Current spread is a year spread.
    /// Expected: Always returns [].
    @Test @MainActor func yearSpreadReturnsEmpty() async throws {
        let calendar = Self.testCalendar
        let yearDate = Self.date(year: 2026, month: 1)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: yearDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [yearSpread, monthSpread])
        )

        let parents = manager.containingParentSpreads(for: yearSpread)
        #expect(parents.isEmpty)
    }

    // MARK: - Month spread

    /// Conditions: Current spread is a month spread (July 2026) and a year spread for 2026 exists.
    /// Expected: Returns the containing year spread.
    @Test @MainActor func monthSpreadReturnsContainingYearSpread() async throws {
        let calendar = Self.testCalendar
        let monthDate = Self.date(year: 2026, month: 7)
        let yearDate = Self.date(year: 2026, month: 1)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread, yearSpread])
        )

        let parents = manager.containingParentSpreads(for: monthSpread)
        #expect(parents.count == 1)
        #expect(parents.first?.id == yearSpread.id)
        #expect(parents.first?.period == .year)
    }

    /// Conditions: Current spread is a month spread (July 2026) and no year spread exists.
    /// Expected: Returns [].
    @Test @MainActor func monthSpreadReturnsEmptyWhenNoYearSpreadExists() async throws {
        let calendar = Self.testCalendar
        let monthDate = Self.date(year: 2026, month: 7)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let otherMonthSpread = DataModel.Spread(period: .month, date: Self.date(year: 2026, month: 8), calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [monthSpread, otherMonthSpread])
        )

        let parents = manager.containingParentSpreads(for: monthSpread)
        #expect(parents.isEmpty)
    }

    // MARK: - Day spread

    /// Conditions: Day spread for July 6, 2026. Month spread for July and year spread for 2026 both exist.
    /// Expected: Returns [monthSpread, yearSpread] in that order (month before year).
    @Test @MainActor func daySpreadReturnsBothParentSpreads() async throws {
        let calendar = Self.testCalendar
        let dayDate = Self.date(year: 2026, month: 7, day: 6)
        let monthDate = Self.date(year: 2026, month: 7)
        let yearDate = Self.date(year: 2026, month: 1)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, monthSpread, yearSpread])
        )

        let parents = manager.containingParentSpreads(for: daySpread)
        #expect(parents.count == 2)
        #expect(parents[0].id == monthSpread.id)
        #expect(parents[1].id == yearSpread.id)
    }

    /// Conditions: Day spread for July 6, 2026. Only year spread for 2026 exists (no month spread).
    /// Expected: Returns [yearSpread] only.
    @Test @MainActor func daySpreadReturnsOnlyYearWhenNoMonthExists() async throws {
        let calendar = Self.testCalendar
        let dayDate = Self.date(year: 2026, month: 7, day: 6)
        let yearDate = Self.date(year: 2026, month: 1)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, yearSpread])
        )

        let parents = manager.containingParentSpreads(for: daySpread)
        #expect(parents.count == 1)
        #expect(parents.first?.id == yearSpread.id)
    }

    /// Conditions: Day spread for July 6, 2026. No parent spreads exist.
    /// Expected: Returns [].
    @Test @MainActor func daySpreadReturnsEmptyWhenNoParentsExist() async throws {
        let calendar = Self.testCalendar
        let dayDate = Self.date(year: 2026, month: 7, day: 6)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: calendar)
        let otherDay = DataModel.Spread(period: .day, date: Self.date(year: 2026, month: 7, day: 7), calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [daySpread, otherDay])
        )

        let parents = manager.containingParentSpreads(for: daySpread)
        #expect(parents.isEmpty)
    }

    // MARK: - Multiday spread

    /// Conditions: Multiday spread for July 1–7, 2026. Month spread for July and year spread for 2026 both exist.
    /// Expected: Returns [monthSpread, yearSpread] in that order.
    @Test @MainActor func multidaySpreadWithinOneMonthReturnsBothParents() async throws {
        let calendar = Self.testCalendar
        let start = Self.date(year: 2026, month: 7, day: 1)
        let end = Self.date(year: 2026, month: 7, day: 7)
        let multidaySpread = DataModel.Spread(startDate: start, endDate: end, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: start, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: start, calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [multidaySpread, monthSpread, yearSpread])
        )

        let parents = manager.containingParentSpreads(for: multidaySpread)
        #expect(parents.count == 2)
        #expect(parents[0].id == monthSpread.id)
        #expect(parents[1].id == yearSpread.id)
    }

    /// Conditions: Multiday spread spanning June 28 – July 4, 2026. Month spreads for June and July both exist, plus year spread for 2026.
    /// Expected: Returns both month spreads and the year spread (3 total).
    @Test @MainActor func multidaySpreadSpanningTwoMonthsReturnsBothMonths() async throws {
        let calendar = Self.testCalendar
        let start = Self.date(year: 2026, month: 6, day: 28)
        let end = Self.date(year: 2026, month: 7, day: 4)
        let multidaySpread = DataModel.Spread(startDate: start, endDate: end, calendar: calendar)
        let juneSpread = DataModel.Spread(period: .month, date: Self.date(year: 2026, month: 6), calendar: calendar)
        let julySpread = DataModel.Spread(period: .month, date: Self.date(year: 2026, month: 7), calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: Self.date(year: 2026, month: 1), calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [multidaySpread, juneSpread, julySpread, yearSpread])
        )

        let parents = manager.containingParentSpreads(for: multidaySpread)
        let parentIDs = Set(parents.map(\.id))
        #expect(parents.count == 3)
        #expect(parentIDs.contains(juneSpread.id))
        #expect(parentIDs.contains(julySpread.id))
        #expect(parentIDs.contains(yearSpread.id))
    }

    /// Conditions: Multiday spread for July 1–7 with no parent spreads.
    /// Expected: Returns [].
    @Test @MainActor func multidaySpreadReturnsEmptyWhenNoParentsExist() async throws {
        let calendar = Self.testCalendar
        let start = Self.date(year: 2026, month: 7, day: 1)
        let end = Self.date(year: 2026, month: 7, day: 7)
        let multidaySpread = DataModel.Spread(startDate: start, endDate: end, calendar: calendar)
        let otherDay = DataModel.Spread(period: .day, date: Self.date(year: 2026, month: 7, day: 3), calendar: calendar)

        let manager = try await JournalManager(
            calendar: calendar,
            spreadRepository: TestSpreadRepository(spreads: [multidaySpread, otherDay])
        )

        let parents = manager.containingParentSpreads(for: multidaySpread)
        #expect(parents.isEmpty)
    }
}
