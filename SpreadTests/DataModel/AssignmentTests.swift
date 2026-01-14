import class Foundation.JSONDecoder
import class Foundation.JSONEncoder
import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.DateComponents
import struct Foundation.TimeZone
import Testing
@testable import Spread

/// Tests for TaskAssignment, NoteAssignment, and AssignmentMatchable protocol.
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

    // MARK: - TaskAssignment Matching Tests

    /// Conditions: TaskAssignment for day June 15, checking same period and date.
    /// Expected: Should return true.
    @Test func testTaskAssignmentMatchesSamePeriodAndDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .day, date: date, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment created at 8am, checking with 8pm same day.
    /// Expected: Should return true (time of day should not affect matching).
    @Test func testTaskAssignmentMatchesWithDifferentTimeOfDay() {
        let morning = makeDate(year: 2026, month: 6, day: 15, hour: 8)
        let evening = makeDate(year: 2026, month: 6, day: 15, hour: 20)
        let assignment = TaskAssignment(period: .day, date: morning, status: .open)

        let result = assignment.matches(period: .day, date: evening, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment for day period, checking with month period.
    /// Expected: Should return false (different periods).
    @Test func testTaskAssignmentDoesNotMatchDifferentPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .month, date: date, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: TaskAssignment for June 15, checking with June 16.
    /// Expected: Should return false (different days).
    @Test func testTaskAssignmentDoesNotMatchDifferentDate() {
        let date1 = makeDate(year: 2026, month: 6, day: 15)
        let date2 = makeDate(year: 2026, month: 6, day: 16)
        let assignment = TaskAssignment(period: .day, date: date1, status: .open)

        let result = assignment.matches(period: .day, date: date2, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: TaskAssignment with day period, checking same date.
    /// Expected: Should return true.
    @Test func testTaskAssignmentMatchesDayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .complete)

        #expect(assignment.matches(period: .day, date: date, calendar: testCalendar) == true)
    }

    /// Conditions: TaskAssignment with month period for mid-month date, checking first of month.
    /// Expected: Should return true (same month).
    @Test func testTaskAssignmentMatchesMonthPeriod() {
        let dateInMonth = makeDate(year: 2026, month: 6, day: 15)
        let firstOfMonth = makeDate(year: 2026, month: 6, day: 1)
        let assignment = TaskAssignment(period: .month, date: dateInMonth, status: .open)

        let result = assignment.matches(period: .month, date: firstOfMonth, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment with month period for day 15, checking day 20.
    /// Expected: Should return true (same month).
    @Test func testTaskAssignmentMatchesMonthPeriodAnyDayInMonth() {
        let day15 = makeDate(year: 2026, month: 6, day: 15)
        let day20 = makeDate(year: 2026, month: 6, day: 20)
        let assignment = TaskAssignment(period: .month, date: day15, status: .migrated)

        let result = assignment.matches(period: .month, date: day20, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment with year period for mid-year date, checking first of year.
    /// Expected: Should return true (same year).
    @Test func testTaskAssignmentMatchesYearPeriod() {
        let dateInYear = makeDate(year: 2026, month: 6, day: 15)
        let firstOfYear = makeDate(year: 2026, month: 1, day: 1)
        let assignment = TaskAssignment(period: .year, date: dateInYear, status: .open)

        let result = assignment.matches(period: .year, date: firstOfYear, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment with year period for January, checking December.
    /// Expected: Should return true (same year).
    @Test func testTaskAssignmentMatchesYearPeriodAnyDayInYear() {
        let january = makeDate(year: 2026, month: 1, day: 15)
        let december = makeDate(year: 2026, month: 12, day: 25)
        let assignment = TaskAssignment(period: .year, date: january, status: .cancelled)

        let result = assignment.matches(period: .year, date: december, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: TaskAssignment with month period for June, checking July.
    /// Expected: Should return false (different months).
    @Test func testTaskAssignmentDoesNotMatchDifferentMonth() {
        let june = makeDate(year: 2026, month: 6, day: 15)
        let july = makeDate(year: 2026, month: 7, day: 15)
        let assignment = TaskAssignment(period: .month, date: june, status: .open)

        let result = assignment.matches(period: .month, date: july, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: TaskAssignment with year period for 2026, checking 2027.
    /// Expected: Should return false (different years).
    @Test func testTaskAssignmentDoesNotMatchDifferentYear() {
        let year2026 = makeDate(year: 2026, month: 6, day: 15)
        let year2027 = makeDate(year: 2027, month: 6, day: 15)
        let assignment = TaskAssignment(period: .year, date: year2026, status: .open)

        let result = assignment.matches(period: .year, date: year2027, calendar: testCalendar)
        #expect(result == false)
    }

    // MARK: - NoteAssignment Matching Tests

    /// Conditions: NoteAssignment for day June 15, checking same period and date.
    /// Expected: Should return true.
    @Test func testNoteAssignmentMatchesSamePeriodAndDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        let result = assignment.matches(period: .day, date: date, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: NoteAssignment created at 8am, checking with 8pm same day.
    /// Expected: Should return true (time of day should not affect matching).
    @Test func testNoteAssignmentMatchesWithDifferentTimeOfDay() {
        let morning = makeDate(year: 2026, month: 6, day: 15, hour: 8)
        let evening = makeDate(year: 2026, month: 6, day: 15, hour: 20)
        let assignment = NoteAssignment(period: .day, date: morning, status: .active)

        let result = assignment.matches(period: .day, date: evening, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: NoteAssignment for day period, checking with month period.
    /// Expected: Should return false (different periods).
    @Test func testNoteAssignmentDoesNotMatchDifferentPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        let result = assignment.matches(period: .month, date: date, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: NoteAssignment for June 15, checking with June 16.
    /// Expected: Should return false (different days).
    @Test func testNoteAssignmentDoesNotMatchDifferentDate() {
        let date1 = makeDate(year: 2026, month: 6, day: 15)
        let date2 = makeDate(year: 2026, month: 6, day: 16)
        let assignment = NoteAssignment(period: .day, date: date1, status: .active)

        let result = assignment.matches(period: .day, date: date2, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: NoteAssignment with day period, checking same date.
    /// Expected: Should return true.
    @Test func testNoteAssignmentMatchesDayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.matches(period: .day, date: date, calendar: testCalendar) == true)
    }

    /// Conditions: NoteAssignment with month period for mid-month date, checking first of month.
    /// Expected: Should return true (same month).
    @Test func testNoteAssignmentMatchesMonthPeriod() {
        let dateInMonth = makeDate(year: 2026, month: 6, day: 15)
        let firstOfMonth = makeDate(year: 2026, month: 6, day: 1)
        let assignment = NoteAssignment(period: .month, date: dateInMonth, status: .active)

        let result = assignment.matches(period: .month, date: firstOfMonth, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: NoteAssignment with year period for mid-year date, checking first of year.
    /// Expected: Should return true (same year).
    @Test func testNoteAssignmentMatchesYearPeriod() {
        let dateInYear = makeDate(year: 2026, month: 6, day: 15)
        let firstOfYear = makeDate(year: 2026, month: 1, day: 1)
        let assignment = NoteAssignment(period: .year, date: dateInYear, status: .active)

        let result = assignment.matches(period: .year, date: firstOfYear, calendar: testCalendar)
        #expect(result == true)
    }

    /// Conditions: NoteAssignment with month period for June, checking July.
    /// Expected: Should return false (different months).
    @Test func testNoteAssignmentDoesNotMatchDifferentMonth() {
        let june = makeDate(year: 2026, month: 6, day: 15)
        let july = makeDate(year: 2026, month: 7, day: 15)
        let assignment = NoteAssignment(period: .month, date: june, status: .active)

        let result = assignment.matches(period: .month, date: july, calendar: testCalendar)
        #expect(result == false)
    }

    /// Conditions: NoteAssignment with year period for 2026, checking 2027.
    /// Expected: Should return false (different years).
    @Test func testNoteAssignmentDoesNotMatchDifferentYear() {
        let year2026 = makeDate(year: 2026, month: 6, day: 15)
        let year2027 = makeDate(year: 2027, month: 6, day: 15)
        let assignment = NoteAssignment(period: .year, date: year2026, status: .active)

        let result = assignment.matches(period: .year, date: year2027, calendar: testCalendar)
        #expect(result == false)
    }

    // MARK: - TaskAssignment Status Tests

    /// Conditions: Create TaskAssignment with .open status.
    /// Expected: Status should be .open.
    @Test func testTaskAssignmentOpenStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        #expect(assignment.status == .open)
    }

    /// Conditions: Create TaskAssignment with .complete status.
    /// Expected: Status should be .complete.
    @Test func testTaskAssignmentCompleteStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .complete)

        #expect(assignment.status == .complete)
    }

    /// Conditions: Create TaskAssignment with .migrated status.
    /// Expected: Status should be .migrated.
    @Test func testTaskAssignmentMigratedStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.status == .migrated)
    }

    /// Conditions: Create TaskAssignment with .cancelled status.
    /// Expected: Status should be .cancelled.
    @Test func testTaskAssignmentCancelledStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .cancelled)

        #expect(assignment.status == .cancelled)
    }

    /// Conditions: Create TaskAssignment with .open status, then update to other statuses.
    /// Expected: Status should update correctly.
    @Test func testTaskAssignmentStatusCanBeUpdated() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        var assignment = TaskAssignment(period: .day, date: date, status: .open)

        assignment.status = .complete
        #expect(assignment.status == .complete)

        assignment.status = .migrated
        #expect(assignment.status == .migrated)

        assignment.status = .cancelled
        #expect(assignment.status == .cancelled)
    }

    /// Conditions: Create TaskAssignment, copy it, modify copy's status.
    /// Expected: Original should be unchanged (value type semantics).
    @Test func testTaskAssignmentIsValueType() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let original = TaskAssignment(period: .day, date: date, status: .open)
        var copy = original

        copy.status = .complete

        #expect(original.status == .open)
        #expect(copy.status == .complete)
    }

    // MARK: - NoteAssignment Status Tests

    /// Conditions: Create NoteAssignment with .active status.
    /// Expected: Status should be .active.
    @Test func testNoteAssignmentActiveStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        #expect(assignment.status == .active)
    }

    /// Conditions: Create NoteAssignment with .migrated status.
    /// Expected: Status should be .migrated.
    @Test func testNoteAssignmentMigratedStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.status == .migrated)
    }

    /// Conditions: Create NoteAssignment with .active status, then update.
    /// Expected: Status should update correctly.
    @Test func testNoteAssignmentStatusCanBeUpdated() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        var assignment = NoteAssignment(period: .day, date: date, status: .active)

        assignment.status = .migrated
        #expect(assignment.status == .migrated)

        assignment.status = .active
        #expect(assignment.status == .active)
    }

    /// Conditions: Create NoteAssignment, copy it, modify copy's status.
    /// Expected: Original should be unchanged (value type semantics).
    @Test func testNoteAssignmentIsValueType() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let original = NoteAssignment(period: .day, date: date, status: .active)
        var copy = original

        copy.status = .migrated

        #expect(original.status == .active)
        #expect(copy.status == .migrated)
    }

    // MARK: - Assignment Codable Tests

    /// Conditions: Encode TaskAssignment to JSON and decode.
    /// Expected: Decoded assignment should have same period and status.
    @Test func testTaskAssignmentIsCodable() throws {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .month, date: date, status: .complete)

        let encoder = JSONEncoder()
        let data = try encoder.encode(assignment)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TaskAssignment.self, from: data)

        #expect(decoded.period == assignment.period)
        #expect(decoded.status == assignment.status)
    }

    /// Conditions: Encode NoteAssignment to JSON and decode.
    /// Expected: Decoded assignment should have same period and status.
    @Test func testNoteAssignmentIsCodable() throws {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .year, date: date, status: .migrated)

        let encoder = JSONEncoder()
        let data = try encoder.encode(assignment)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NoteAssignment.self, from: data)

        #expect(decoded.period == assignment.period)
        #expect(decoded.status == assignment.status)
    }

    // MARK: - Assignment Hashable Tests

    /// Conditions: Create identical TaskAssignments and one with different status.
    /// Expected: Identical assignments should be equal and hash together; different should not.
    @Test func testTaskAssignmentIsHashable() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment1 = TaskAssignment(period: .day, date: date, status: .open)
        let assignment2 = TaskAssignment(period: .day, date: date, status: .open)
        let assignment3 = TaskAssignment(period: .day, date: date, status: .complete)

        #expect(assignment1 == assignment2)
        #expect(assignment1 != assignment3)

        var set: Set<TaskAssignment> = []
        set.insert(assignment1)
        set.insert(assignment2)
        #expect(set.count == 1)
    }

    /// Conditions: Create identical NoteAssignments and one with different status.
    /// Expected: Identical assignments should be equal and hash together; different should not.
    @Test func testNoteAssignmentIsHashable() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment1 = NoteAssignment(period: .day, date: date, status: .active)
        let assignment2 = NoteAssignment(period: .day, date: date, status: .active)
        let assignment3 = NoteAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment1 == assignment2)
        #expect(assignment1 != assignment3)

        var set: Set<NoteAssignment> = []
        set.insert(assignment1)
        set.insert(assignment2)
        #expect(set.count == 1)
    }

    // MARK: - Edge Cases

    /// Conditions: TaskAssignment for Dec 31 2026, checking Dec 31 and Jan 1 2027.
    /// Expected: Should match Dec 31, not match Jan 1 (year boundary).
    @Test func testTaskAssignmentMatchesAtYearBoundary() {
        let dec31 = makeDate(year: 2026, month: 12, day: 31)
        let jan1 = makeDate(year: 2027, month: 1, day: 1)
        let assignment = TaskAssignment(period: .year, date: dec31, status: .open)

        #expect(assignment.matches(period: .year, date: dec31, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .year, date: jan1, calendar: testCalendar) == false)
    }

    /// Conditions: TaskAssignment for June 30, checking June 30 and July 1.
    /// Expected: Should match June 30, not match July 1 (month boundary).
    @Test func testTaskAssignmentMatchesAtMonthBoundary() {
        let june30 = makeDate(year: 2026, month: 6, day: 30)
        let july1 = makeDate(year: 2026, month: 7, day: 1)
        let assignment = TaskAssignment(period: .month, date: june30, status: .open)

        #expect(assignment.matches(period: .month, date: june30, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: july1, calendar: testCalendar) == false)
    }

    /// Conditions: NoteAssignment for Feb 2024 (leap year), checking Feb 28, 29, and Mar 1.
    /// Expected: Should match Feb 28 and 29, not match Mar 1.
    @Test func testNoteAssignmentMatchesAtLeapYearBoundary() {
        let feb28 = makeDate(year: 2024, month: 2, day: 28)
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let march1 = makeDate(year: 2024, month: 3, day: 1)

        let assignment = NoteAssignment(period: .month, date: feb28, status: .active)

        #expect(assignment.matches(period: .month, date: feb29, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: march1, calendar: testCalendar) == false)
    }

    /// Conditions: TaskAssignment with multiday period, checking same date.
    /// Expected: Should match (multiday uses day normalization).
    @Test func testTaskAssignmentMatchesMultidayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .multiday, date: date, status: .open)

        #expect(assignment.matches(period: .multiday, date: date, calendar: testCalendar) == true)
    }

    /// Conditions: NoteAssignment with multiday period, checking same date.
    /// Expected: Should match (multiday uses day normalization).
    @Test func testNoteAssignmentMatchesMultidayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .multiday, date: date, status: .active)

        #expect(assignment.matches(period: .multiday, date: date, calendar: testCalendar) == true)
    }
}
