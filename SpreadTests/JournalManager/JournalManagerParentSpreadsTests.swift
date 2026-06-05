import Foundation
import Testing
@testable import Spread

/// Tests for `JournalManager.parentSpreads(for:)`.
@Suite("JournalManager Parent Spreads Tests")
struct JournalManagerParentSpreadsTests {

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    // MARK: - .year spread

    // Conditions: `parentSpreads(for:)` is called with a `.year` spread.
    // Expected: Returns an empty array — year spreads have no ancestors.
    @Test @MainActor func testYearSpreadReturnsNoParents() async throws {
        let calendar = Self.testCalendar
        let yearDate = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let yearSpread = DataModel.Spread(period: .year, date: yearDate, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [yearSpread])
        )

        let parents = manager.parentSpreads(for: yearSpread)

        #expect(parents.isEmpty)
    }

    // MARK: - .month spread

    // Conditions: A `.month` spread exists and a matching `.year` spread exists in the journal.
    // Expected: Returns one entry with period `.year` and a non-nil spread.
    @Test @MainActor func testMonthSpreadReturnsYearParent() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 1))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: date, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [monthSpread, yearSpread])
        )

        let parents = manager.parentSpreads(for: monthSpread)

        #expect(parents.count == 1)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread?.id == yearSpread.id)
    }

    // Conditions: A `.month` spread exists but no `.year` spread exists in the journal.
    // Expected: Returns one entry with period `.year` and a nil spread.
    @Test @MainActor func testMonthSpreadReturnsNilWhenNoYearSpread() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 1))!
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [monthSpread])
        )

        let parents = manager.parentSpreads(for: monthSpread)

        #expect(parents.count == 1)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread == nil)
    }

    // MARK: - .day spread

    // Conditions: A `.day` spread exists with matching `.year` and `.month` spreads in the journal.
    // Expected: Returns two entries — (.year, spread), (.month, spread) — in that order.
    @Test @MainActor func testDaySpreadReturnsTwoParentsWhenBothExist() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 5))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: date, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: date, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread, monthSpread, yearSpread])
        )

        let parents = manager.parentSpreads(for: daySpread)

        #expect(parents.count == 2)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread?.id == yearSpread.id)
        #expect(parents[1].period == .month)
        #expect(parents[1].spread?.id == monthSpread.id)
    }

    // Conditions: A `.day` spread exists but no parent spreads exist in the journal.
    // Expected: Returns two entries with nil spreads — (.year, nil), (.month, nil).
    @Test @MainActor func testDaySpreadReturnsNilEntriesWhenNoParentSpreads() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 5))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread])
        )

        let parents = manager.parentSpreads(for: daySpread)

        #expect(parents.count == 2)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread == nil)
        #expect(parents[1].period == .month)
        #expect(parents[1].spread == nil)
    }

    // Conditions: A `.day` spread exists and a `.multiday` spread covers that day.
    // Expected: Returns three entries — (.year, spread?), (.month, spread?), (.multiday, spread).
    @Test @MainActor func testDaySpreadIncludesMultidayWhenCoveringSpreadExists() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 5))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)
        let multidayStart = calendar.date(from: .init(year: 2026, month: 6, day: 3))!
        let multidayEnd = calendar.date(from: .init(year: 2026, month: 6, day: 9))!
        let multidaySpread = DataModel.Spread(startDate: multidayStart, endDate: multidayEnd, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread, multidaySpread])
        )

        let parents = manager.parentSpreads(for: daySpread)

        #expect(parents.count == 3)
        #expect(parents[0].period == .year)
        #expect(parents[1].period == .month)
        #expect(parents[2].period == .multiday)
        #expect(parents[2].spread?.id == multidaySpread.id)
    }

    // Conditions: A `.day` spread exists and no multiday spread covers that day.
    // Expected: Returns only two entries — (.year, nil), (.month, nil). Multiday is omitted entirely.
    @Test @MainActor func testDaySpreadOmitsMultidayWhenNoCoveringSpreadExists() async throws {
        let calendar = Self.testCalendar
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 5))!
        let daySpread = DataModel.Spread(period: .day, date: date, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread])
        )

        let parents = manager.parentSpreads(for: daySpread)

        #expect(parents.count == 2)
        #expect(parents[0].period == .year)
        #expect(parents[1].period == .month)
        #expect(!parents.contains(where: { $0.period == .multiday }))
    }

    // MARK: - .multiday spread

    // Conditions: A `.multiday` spread exists with matching `.year` and `.month` spreads for its start date.
    // Expected: Returns (.year, spread), (.month, spread) — using the start date as reference.
    @Test @MainActor func testMultidaySpreadReturnsTwoParentsUsingStartDate() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 6, day: 3))!
        let endDate = calendar.date(from: .init(year: 2026, month: 6, day: 9))!
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: startDate, calendar: calendar)
        let yearSpread = DataModel.Spread(period: .year, date: startDate, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [multidaySpread, monthSpread, yearSpread])
        )

        let parents = manager.parentSpreads(for: multidaySpread)

        #expect(parents.count == 2)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread?.id == yearSpread.id)
        #expect(parents[1].period == .month)
        #expect(parents[1].spread?.id == monthSpread.id)
    }

    // Conditions: A `.multiday` spread exists but no parent spreads exist in the journal.
    // Expected: Returns two entries with nil spreads.
    @Test @MainActor func testMultidaySpreadReturnsNilEntriesWhenNoParentSpreads() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 6, day: 3))!
        let endDate = calendar.date(from: .init(year: 2026, month: 6, day: 9))!
        let multidaySpread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
        let manager = try await JournalManager.make(
            calendar: calendar,
            spreadRepository: InMemorySpreadRepository(spreads: [multidaySpread])
        )

        let parents = manager.parentSpreads(for: multidaySpread)

        #expect(parents.count == 2)
        #expect(parents[0].period == .year)
        #expect(parents[0].spread == nil)
        #expect(parents[1].period == .month)
        #expect(parents[1].spread == nil)
    }
}
