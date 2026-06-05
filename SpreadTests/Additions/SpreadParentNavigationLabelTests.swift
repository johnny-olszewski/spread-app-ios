import Foundation
import Testing
@testable import Spread

/// Tests for `DataModel.Spread.parentNavigationLabel(calendar:)`.
@Suite("Spread Parent Navigation Label Tests")
struct SpreadParentNavigationLabelTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    // MARK: - Year spread

    // Conditions: `parentNavigationLabel` is called on a `.year` spread for 2026.
    // Expected: Returns the four-digit year string "2026".
    @Test func testYearSpreadLabelIsYYYY() {
        let date = calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let spread = DataModel.Spread(period: .year, date: date, calendar: calendar)

        #expect(spread.parentNavigationLabel(calendar: calendar) == "2026")
    }

    // MARK: - Month spread

    // Conditions: `parentNavigationLabel` is called on a `.month` spread for June 2026.
    // Expected: Returns the abbreviated month name "Jun".
    @Test func testMonthSpreadLabelIsMMM() {
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 1))!
        let spread = DataModel.Spread(period: .month, date: date, calendar: calendar)

        #expect(spread.parentNavigationLabel(calendar: calendar) == "Jun")
    }

    // MARK: - Multiday spread

    // Conditions: `parentNavigationLabel` is called on a `.multiday` spread from Jun 3 to Jun 9, 2026.
    // Expected: Returns "3 Jun – 9 Jun".
    @Test func testMultidaySpreadLabelIsDDMMMRangeDDMMM() {
        let startDate = calendar.date(from: .init(year: 2026, month: 6, day: 3))!
        let endDate = calendar.date(from: .init(year: 2026, month: 6, day: 9))!
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)

        #expect(spread.parentNavigationLabel(calendar: calendar) == "3 Jun – 9 Jun")
    }

    // MARK: - Day spread

    // Conditions: `parentNavigationLabel` is called on a `.day` spread.
    // Expected: Returns an empty string — day spreads are not parent targets.
    @Test func testDaySpreadLabelIsEmpty() {
        let date = calendar.date(from: .init(year: 2026, month: 6, day: 5))!
        let spread = DataModel.Spread(period: .day, date: date, calendar: calendar)

        #expect(spread.parentNavigationLabel(calendar: calendar) == "")
    }
}
