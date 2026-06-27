import Testing
import Foundation
@testable import JohnnyOFoundationUI

@Suite("CalendarView — month range computation")
struct CalendarViewTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(year: Int, month: Int, day: Int = 1) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)!
    }

    // When startDate and endDate fall in the same calendar month,
    // the result should contain exactly one month.
    @Test func sameMonthReturnsOneMonth() {
        let start = date(year: 2025, month: 6, day: 10)
        let end   = date(year: 2025, month: 6, day: 25)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        #expect(result.count == 1)
    }

    // When startDate is the first day of January and endDate is the last day of December
    // in the same year, the result should contain all 12 months.
    @Test func fullYearReturnsTwelveMonths() {
        let start = date(year: 2025, month: 1, day: 1)
        let end   = date(year: 2025, month: 12, day: 31)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        #expect(result.count == 12)
    }

    // When startDate and endDate span a year boundary (e.g. Nov 2025 to Feb 2026),
    // the result should contain exactly the months covered (4 months).
    @Test func crossYearBoundaryReturnsCorrectCount() {
        let start = date(year: 2025, month: 11, day: 1)
        let end   = date(year: 2026, month: 2, day: 1)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        #expect(result.count == 4)
    }

    // All returned dates should be the first of their respective month,
    // and should be in strictly ascending order.
    @Test func resultsAreAscendingFirstOfMonth() {
        let start = date(year: 2025, month: 3, day: 15)
        let end   = date(year: 2025, month: 6, day: 10)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        for (idx, d) in result.enumerated() {
            let comps = calendar.dateComponents([.day], from: d)
            #expect(comps.day == 1, "Month at index \(idx) is not the first of the month")
            if idx > 0 {
                #expect(result[idx - 1] < d, "Months not in ascending order at index \(idx)")
            }
        }
    }

    // When startDate is after endDate, the result should be empty.
    @Test func startAfterEndReturnsEmpty() {
        let start = date(year: 2025, month: 6, day: 1)
        let end   = date(year: 2025, month: 3, day: 1)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        #expect(result.isEmpty)
    }

    // The boundary months must always be included even when startDate / endDate
    // are mid-month (not the first or last day).
    @Test func midMonthBoundariesAreInclusive() {
        let start = date(year: 2025, month: 4, day: 20)
        let end   = date(year: 2025, month: 7, day: 5)
        let result = monthDateRange(from: start, to: end, calendar: calendar)
        // April, May, June, July → 4 months
        #expect(result.count == 4)
        let firstComps = calendar.dateComponents([.year, .month], from: result.first!)
        let lastComps  = calendar.dateComponents([.year, .month], from: result.last!)
        #expect(firstComps.month == 4)
        #expect(lastComps.month == 7)
    }
}
