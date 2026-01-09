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

    @Test func testTaskAssignmentMatchesSamePeriodAndDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .day, date: date, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentMatchesWithDifferentTimeOfDay() {
        let morning = makeDate(year: 2026, month: 6, day: 15, hour: 8)
        let evening = makeDate(year: 2026, month: 6, day: 15, hour: 20)
        let assignment = TaskAssignment(period: .day, date: morning, status: .open)

        let result = assignment.matches(period: .day, date: evening, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentDoesNotMatchDifferentPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        let result = assignment.matches(period: .month, date: date, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testTaskAssignmentDoesNotMatchDifferentDate() {
        let date1 = makeDate(year: 2026, month: 6, day: 15)
        let date2 = makeDate(year: 2026, month: 6, day: 16)
        let assignment = TaskAssignment(period: .day, date: date1, status: .open)

        let result = assignment.matches(period: .day, date: date2, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testTaskAssignmentMatchesDayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .complete)

        #expect(assignment.matches(period: .day, date: date, calendar: testCalendar) == true)
    }

    @Test func testTaskAssignmentMatchesMonthPeriod() {
        let dateInMonth = makeDate(year: 2026, month: 6, day: 15)
        let firstOfMonth = makeDate(year: 2026, month: 6, day: 1)
        let assignment = TaskAssignment(period: .month, date: dateInMonth, status: .open)

        let result = assignment.matches(period: .month, date: firstOfMonth, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentMatchesMonthPeriodAnyDayInMonth() {
        let day15 = makeDate(year: 2026, month: 6, day: 15)
        let day20 = makeDate(year: 2026, month: 6, day: 20)
        let assignment = TaskAssignment(period: .month, date: day15, status: .migrated)

        let result = assignment.matches(period: .month, date: day20, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentMatchesYearPeriod() {
        let dateInYear = makeDate(year: 2026, month: 6, day: 15)
        let firstOfYear = makeDate(year: 2026, month: 1, day: 1)
        let assignment = TaskAssignment(period: .year, date: dateInYear, status: .open)

        let result = assignment.matches(period: .year, date: firstOfYear, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentMatchesYearPeriodAnyDayInYear() {
        let january = makeDate(year: 2026, month: 1, day: 15)
        let december = makeDate(year: 2026, month: 12, day: 25)
        let assignment = TaskAssignment(period: .year, date: january, status: .cancelled)

        let result = assignment.matches(period: .year, date: december, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testTaskAssignmentDoesNotMatchDifferentMonth() {
        let june = makeDate(year: 2026, month: 6, day: 15)
        let july = makeDate(year: 2026, month: 7, day: 15)
        let assignment = TaskAssignment(period: .month, date: june, status: .open)

        let result = assignment.matches(period: .month, date: july, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testTaskAssignmentDoesNotMatchDifferentYear() {
        let year2026 = makeDate(year: 2026, month: 6, day: 15)
        let year2027 = makeDate(year: 2027, month: 6, day: 15)
        let assignment = TaskAssignment(period: .year, date: year2026, status: .open)

        let result = assignment.matches(period: .year, date: year2027, calendar: testCalendar)
        #expect(result == false)
    }

    // MARK: - NoteAssignment Matching Tests

    @Test func testNoteAssignmentMatchesSamePeriodAndDate() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        let result = assignment.matches(period: .day, date: date, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testNoteAssignmentMatchesWithDifferentTimeOfDay() {
        let morning = makeDate(year: 2026, month: 6, day: 15, hour: 8)
        let evening = makeDate(year: 2026, month: 6, day: 15, hour: 20)
        let assignment = NoteAssignment(period: .day, date: morning, status: .active)

        let result = assignment.matches(period: .day, date: evening, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testNoteAssignmentDoesNotMatchDifferentPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        let result = assignment.matches(period: .month, date: date, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testNoteAssignmentDoesNotMatchDifferentDate() {
        let date1 = makeDate(year: 2026, month: 6, day: 15)
        let date2 = makeDate(year: 2026, month: 6, day: 16)
        let assignment = NoteAssignment(period: .day, date: date1, status: .active)

        let result = assignment.matches(period: .day, date: date2, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testNoteAssignmentMatchesDayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.matches(period: .day, date: date, calendar: testCalendar) == true)
    }

    @Test func testNoteAssignmentMatchesMonthPeriod() {
        let dateInMonth = makeDate(year: 2026, month: 6, day: 15)
        let firstOfMonth = makeDate(year: 2026, month: 6, day: 1)
        let assignment = NoteAssignment(period: .month, date: dateInMonth, status: .active)

        let result = assignment.matches(period: .month, date: firstOfMonth, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testNoteAssignmentMatchesYearPeriod() {
        let dateInYear = makeDate(year: 2026, month: 6, day: 15)
        let firstOfYear = makeDate(year: 2026, month: 1, day: 1)
        let assignment = NoteAssignment(period: .year, date: dateInYear, status: .active)

        let result = assignment.matches(period: .year, date: firstOfYear, calendar: testCalendar)
        #expect(result == true)
    }

    @Test func testNoteAssignmentDoesNotMatchDifferentMonth() {
        let june = makeDate(year: 2026, month: 6, day: 15)
        let july = makeDate(year: 2026, month: 7, day: 15)
        let assignment = NoteAssignment(period: .month, date: june, status: .active)

        let result = assignment.matches(period: .month, date: july, calendar: testCalendar)
        #expect(result == false)
    }

    @Test func testNoteAssignmentDoesNotMatchDifferentYear() {
        let year2026 = makeDate(year: 2026, month: 6, day: 15)
        let year2027 = makeDate(year: 2027, month: 6, day: 15)
        let assignment = NoteAssignment(period: .year, date: year2026, status: .active)

        let result = assignment.matches(period: .year, date: year2027, calendar: testCalendar)
        #expect(result == false)
    }

    // MARK: - TaskAssignment Status Tests

    @Test func testTaskAssignmentOpenStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .open)

        #expect(assignment.status == .open)
    }

    @Test func testTaskAssignmentCompleteStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .complete)

        #expect(assignment.status == .complete)
    }

    @Test func testTaskAssignmentMigratedStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.status == .migrated)
    }

    @Test func testTaskAssignmentCancelledStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .day, date: date, status: .cancelled)

        #expect(assignment.status == .cancelled)
    }

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

    @Test func testTaskAssignmentIsValueType() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let original = TaskAssignment(period: .day, date: date, status: .open)
        var copy = original

        copy.status = .complete

        #expect(original.status == .open)
        #expect(copy.status == .complete)
    }

    // MARK: - NoteAssignment Status Tests

    @Test func testNoteAssignmentActiveStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .active)

        #expect(assignment.status == .active)
    }

    @Test func testNoteAssignmentMigratedStatus() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .day, date: date, status: .migrated)

        #expect(assignment.status == .migrated)
    }

    @Test func testNoteAssignmentStatusCanBeUpdated() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        var assignment = NoteAssignment(period: .day, date: date, status: .active)

        assignment.status = .migrated
        #expect(assignment.status == .migrated)

        assignment.status = .active
        #expect(assignment.status == .active)
    }

    @Test func testNoteAssignmentIsValueType() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let original = NoteAssignment(period: .day, date: date, status: .active)
        var copy = original

        copy.status = .migrated

        #expect(original.status == .active)
        #expect(copy.status == .migrated)
    }

    // MARK: - Assignment Codable Tests

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

    @Test func testTaskAssignmentMatchesAtYearBoundary() {
        let dec31 = makeDate(year: 2026, month: 12, day: 31)
        let jan1 = makeDate(year: 2027, month: 1, day: 1)
        let assignment = TaskAssignment(period: .year, date: dec31, status: .open)

        #expect(assignment.matches(period: .year, date: dec31, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .year, date: jan1, calendar: testCalendar) == false)
    }

    @Test func testTaskAssignmentMatchesAtMonthBoundary() {
        let june30 = makeDate(year: 2026, month: 6, day: 30)
        let july1 = makeDate(year: 2026, month: 7, day: 1)
        let assignment = TaskAssignment(period: .month, date: june30, status: .open)

        #expect(assignment.matches(period: .month, date: june30, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: july1, calendar: testCalendar) == false)
    }

    @Test func testNoteAssignmentMatchesAtLeapYearBoundary() {
        let feb28 = makeDate(year: 2024, month: 2, day: 28)
        let feb29 = makeDate(year: 2024, month: 2, day: 29)
        let march1 = makeDate(year: 2024, month: 3, day: 1)

        let assignment = NoteAssignment(period: .month, date: feb28, status: .active)

        #expect(assignment.matches(period: .month, date: feb29, calendar: testCalendar) == true)
        #expect(assignment.matches(period: .month, date: march1, calendar: testCalendar) == false)
    }

    @Test func testTaskAssignmentMatchesMultidayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = TaskAssignment(period: .multiday, date: date, status: .open)

        #expect(assignment.matches(period: .multiday, date: date, calendar: testCalendar) == true)
    }

    @Test func testNoteAssignmentMatchesMultidayPeriod() {
        let date = makeDate(year: 2026, month: 6, day: 15)
        let assignment = NoteAssignment(period: .multiday, date: date, status: .active)

        #expect(assignment.matches(period: .multiday, date: date, calendar: testCalendar) == true)
    }
}
