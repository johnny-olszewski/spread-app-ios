import Foundation
import Testing
@testable import Spread

/// Tests for `Assignment`.
struct AssignmentTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return testCalendar.date(from: components)!
    }

    // MARK: - Assignment Matching Tests

    /// Conditions: Assignment for day June 15, checking same period and date.
    /// Expected: Should return true.
    @Test func testAssignmentMatchesSamePeriodAndDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .day, date: date, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment created at 8am, checking with 8pm same day.
    /// Expected: Should return true (time of day should not affect matching).
    @Test func testAssignmentMatchesWithDifferentTimeOfDay() {
        let morning = makeDate(year: 2026, month: 6, day: 15, hour: 8)
        let evening = makeDate(year: 2026, month: 6, day: 15, hour: 20)
        let assignment = Assignment(period: .day, date: morning, status: .open)

        let result = assignment.matches(period: .day, date: evening, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment for day period, checking with month period.
    /// Expected: Should return false (different periods).
    @Test func testAssignmentDoesNotMatchDifferentPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .month, date: date, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: Assignment for June 15, checking with June 16.
    /// Expected: Should return false (different days).
    @Test func testAssignmentDoesNotMatchDifferentDate() {
        let date1 = makeDate(year: 2026, month: 6, day: 15)
        let date2 = makeDate(year: 2026, month: 6, day: 16)
        let assignment = Assignment(period: .day, date: date1, status: .open)

        let result = assignment.matches(period: .day, date: date2, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: Assignment with day period, checking same date.
    /// Expected: Should return true.
    @Test func testAssignmentMatchesDayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .complete)

        #expect(assignment.matches(period: .day, date: date, calendar: testCalendar) == true)
    }

    /// Conditions: Assignment with month period for mid-month date, checking first of month.
    /// Expected: Should return true (same month).
    @Test func testAssignmentMatchesMonthPeriod() {
        let dateInMonth = makeDate(year: 2026, month: 6, day: 15)
        let firstOfMonth = makeDate(year: 2026, month: 6, day: 1)
        let assignment = Assignment(period: .month, date: dateInMonth, status: .open)

        let result = assignment.matches(period: .month, date: firstOfMonth, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment with month period for day 15, checking day 20.
    /// Expected: Should return true (same month).
    @Test func testAssignmentMatchesMonthPeriodAnyDayInMonth() {
        let day15 = makeDate(year: 2026, month: 6, day: 15)
        let day20 = makeDate(year: 2026, month: 6, day: 20)
        let assignment = Assignment(period: .month, date: day15, status: .migrated)

        let result = assignment.matches(period: .month, date: day20, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment with year period for mid-year date, checking first of year.
    /// Expected: Should return true (same year).
    @Test func testAssignmentMatchesYearPeriod() {
        let dateInYear = makeDate(year: 2026, month: 6, day: 15)
        let firstOfYear = makeDate(year: 2026, month: 1, day: 1)
        let assignment = Assignment(period: .year, date: dateInYear, status: .open)

        let result = assignment.matches(period: .year, date: firstOfYear, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment with year period for January, checking December.
    /// Expected: Should return true (same year).
    @Test func testAssignmentMatchesYearPeriodAnyDayInYear() {
        let january = makeDate(year: 2026, month: 1, day: 15)
        let december = makeDate(year: 2026, month: 12, day: 25)
        let assignment = Assignment(period: .year, date: january, status: .cancelled)

        let result = assignment.matches(period: .year, date: december, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: Assignment with month period for June, checking July.
    /// Expected: Should return false (different months).
    @Test func testAssignmentDoesNotMatchDifferentMonth() {
        let june = makeDate(year: 2026, month: 6, day: 15)
        let july = makeDate(year: 2026, month: 7, day: 15)
        let assignment = Assignment(period: .month, date: june, status: .open)

        let result = assignment.matches(period: .month, date: july, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: Assignment with year period for 2026, checking 2027.
    /// Expected: Should return false (different years).
    @Test func testAssignmentDoesNotMatchDifferentYear() {
        let year2026 = makeDate(year: 2026, month: 6, day: 15)
        let year2027 = makeDate(year: 2027, month: 6, day: 15)
        let assignment = Assignment(period: .year, date: year2026, status: .open)

        let result = assignment.matches(period: .year, date: year2027, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testAssignmentPrefersExplicitSpreadIdentityForMultidayMatches() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let matchingSpreadID = UUID()
        let assignment = Assignment(
            period: .multiday,
            date: date,
            spreadID: matchingSpreadID,
            status: .open
        )

        #expect(assignment.matches(period: .multiday, date: date, spreadID: matchingSpreadID, calendar: testCalendar))
        #expect(!assignment.matches(period: .multiday, date: date, spreadID: UUID(), calendar: testCalendar))
    }

    // MARK: - Assignment Status Tests

    /// Conditions: Create Assignment with .open status.
    /// Expected: Status should be .open.
    @Test func testAssignmentOpenStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .open)

        #expect(assignment.status == .open)
    }

    /// Conditions: Create Assignment with .complete status.
    /// Expected: Status should be .complete.
    @Test func testAssignmentCompleteStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .complete)

        #expect(assignment.status == .complete)
    }

    /// Conditions: Create Assignment with .migrated status.
    /// Expected: Status should be .migrated.
    @Test func testAssignmentMigratedStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .migrated)

        #expect(assignment.status == .migrated)
    }

    /// Conditions: Create Assignment with .cancelled status.
    /// Expected: Status should be .cancelled.
    @Test func testAssignmentCancelledStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .cancelled)

        #expect(assignment.status == .cancelled)
    }

    /// Conditions: Create Assignment with .active status.
    /// Expected: Status should be .active.
    @Test func testAssignmentActiveStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .day, date: date, status: .active)

        #expect(assignment.status == .active)
    }

    /// Conditions: Create Assignment with .open status, then update to other statuses.
    /// Expected: Status should update correctly.
    @Test func testAssignmentStatusCanBeUpdated() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        var assignment = Assignment(period: .day, date: date, status: .open)

        assignment.status = .complete
        #expect(assignment.status == .complete)

        assignment.status = .migrated
        #expect(assignment.status == .migrated)

        assignment.status = .cancelled
        #expect(assignment.status == .cancelled)
    }

    /// Conditions: Create Assignment, copy it, modify copy's status.
    /// Expected: Original should be unchanged (value type semantics).
    @Test func testAssignmentIsValueType() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let original = Assignment(period: .day, date: date, status: .open)
        var copy = original

        copy.status = .complete

        #expect(original.status == .open)
        #expect(copy.status == .complete)
    }

    // MARK: - Assignment Codable Tests

    /// Conditions: Encode Assignment to JSON and decode.
    /// Expected: Decoded assignment should have same period and status.
    @Test func testAssignmentIsCodable() throws {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .month, date: date, status: .complete)

        let encoder = JSONEncoder()
        let data = try encoder.encode(assignment)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Assignment.self, from: data)

        #expect(decoded.period == assignment.period)
        #expect(decoded.status == assignment.status)
        #expect(decoded.id == assignment.id)
    }

    // MARK: - Assignment Hashable Tests

    /// Conditions: Create identical assignments and one with different status.
    /// Expected: Identical assignments should be equal and hash together; different should not.
    @Test func testAssignmentIsHashable() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let stableID = UUID()
        let assignment1 = Assignment(id: stableID, period: .day, date: date, status: .open)
        let assignment2 = Assignment(id: stableID, period: .day, date: date, status: .open)
        let assignment3 = Assignment(period: .day, date: date, status: .complete)

        #expect(assignment1 == assignment2)
        #expect(assignment1 != assignment3)

        var set: Set<Assignment> = []
        set.insert(assignment1)
        set.insert(assignment2)
        #expect(set.count == 1)
    }

    /// Conditions: Legacy assignment JSON missing `id`.
    /// Expected: Decode succeeds and synthesizes a durable ID.
    @Test func testAssignmentDecodesLegacyPayloadWithoutID() throws {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let json = """
        {"period":"day","date":\(date.timeIntervalSinceReferenceDate),"status":"open"}
        """

        let decoded = try JSONDecoder().decode(Assignment.self, from: Data(json.utf8))

        #expect(decoded.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        #expect(decoded.period == .day)
        #expect(decoded.status == .open)
    }

    // MARK: - Edge Cases

    /// Conditions: Assignment for Dec 31 2026, checking Dec 31 and Jan 1 2027.
    /// Expected: Should match Dec 31, not match Jan 1 (year boundary).
    @Test func testAssignmentMatchesAtYearBoundary() {
        let dec31 = makeDate(year: 2026, month: 12, day: 31)
        let jan1 = makeDate(year: 2027, month: 1, day: 1)
        let assignment = Assignment(period: .year, date: dec31, status: .open)

        #expect(assignment.matches(period: .year, date: dec31, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .year, date: jan1, calendar: testCalendar) == false)
    }

    /// Conditions: Assignment for June 30, checking June 30 and July 1.
    /// Expected: Should match June 30, not match July 1 (month boundary).
    @Test func testAssignmentMatchesAtMonthBoundary() {
        let june30 = makeDate(year: 2026, month: 6, day: 30)
        let july1 = makeDate(year: 2026, month: 7, day: 1)
        let assignment = Assignment(period: .month, date: june30, status: .open)

        #expect(assignment.matches(period: .month, date: june30, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: july1, calendar: testCalendar) == false)
    }

    /// Conditions: Assignment for Feb 2024 (leap year), checking Feb 28, 29, and Mar 1.
    /// Expected: Should match Feb 28 and 29, not match Mar 1.
    @Test func testAssignmentMatchesAtLeapYearBoundary() {
        let feb28 = makeDate(year: 2024, month: 2, day: 28)
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let march1 = makeDate(year: 2024, month: 3, day: 1)

        let assignment = Assignment(period: .month, date: feb28, status: .active)

        #expect(assignment.matches(period: .month, date: feb29, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: march1, calendar: testCalendar) == false)
    }

    /// Conditions: Assignment with multiday period, checking same date.
    /// Expected: Should match (multiday uses day normalization).
    @Test func testAssignmentMatchesMultidayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = Assignment(period: .multiday, date: date, status: .open)

        #expect(assignment.matches(period: .multiday, date: date, calendar: testCalendar) == true)
    }
}
