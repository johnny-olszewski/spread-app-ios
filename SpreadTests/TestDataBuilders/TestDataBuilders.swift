import Foundation
@testable import Spread

/// Parameterized test data factories for consistent, repeatable test fixtures.
///
/// All dates use a fixed reference point (2026-06-15) to avoid sensitivity
/// to the system clock. Methods accept `calendar` and `today` so tests can
/// control time-zone and date context.
enum TestDataBuilders {

    // MARK: - Fixed Reference Values

    /// Fixed test year (2026).
    static let testYear = 2026

    /// Fixed test month (June — mid-year, avoids year-boundary edge cases).
    static let testMonth = 6

    /// Fixed test day (15 — mid-month, avoids month-boundary edge cases).
    static let testDay = 15

    /// UTC Gregorian calendar for deterministic date calculations.
    static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// The fixed test date: 2026-06-15 00:00:00 UTC.
    static var testDate: Date {
        testCalendar.date(from: DateComponents(year: testYear, month: testMonth, day: testDay))!
    }

    // MARK: - Date Helpers

    /// Creates a date from year/month/day components in the given calendar.
    static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar = testCalendar
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
