import Foundation
import Testing
@testable import Spread

struct DataModelTaskMigrationOptionsTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Conditions: A task with `.complete` status (not `.open`).
    /// Expected: No migration options — only open tasks can be migrated.
    @Test func testNonOpenTaskHasNoMigrationOptions() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let task = DataModel.Task(title: "Done", date: today, period: .day, status: .complete)

        #expect(task.migrationOptions(today: today, calendar: calendar).isEmpty)
    }

    /// Conditions: An open task with no preferred date, evaluated on April 15, 2026.
    /// Expected: All four candidates (today, tomorrow, next month 1st, next month same day)
    /// are present — nothing is excluded as "already there" since there's no current date.
    @Test func testOpenTaskWithNoDateHasAllFourCandidates() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let task = DataModel.Task(title: "Someday", period: nil, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)

        #expect(Set(options.map(\.kind)) == Set([.today, .tomorrow, .nextMonth, .nextMonthSameDay]))
    }

    /// Conditions: An open day-period task already assigned to today, evaluated on April 15, 2026.
    /// Expected: The "Today" candidate is excluded — migrating a task to where it already is
    /// isn't a real candidate.
    @Test func testTaskAlreadyOnTodayExcludesTodayCandidate() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let task = DataModel.Task(title: "Already today", date: today, period: .day, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)

        #expect(!options.map(\.kind).contains(.today))
        #expect(options.map(\.kind).contains(.tomorrow))
    }

    /// Conditions: An open day-period task assigned to tomorrow, evaluated on April 15, 2026.
    /// Expected: The "Tomorrow" candidate is excluded for the same "already there" reason.
    @Test func testTaskAlreadyOnTomorrowExcludesTomorrowCandidate() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let tomorrow = makeDate(year: 2026, month: 4, day: 16)
        let task = DataModel.Task(title: "Already tomorrow", date: tomorrow, period: .day, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)

        #expect(!options.map(\.kind).contains(.tomorrow))
        #expect(options.map(\.kind).contains(.today))
    }

    /// Conditions: Evaluated on April 15, 2026 (today's day-of-month is 15).
    /// Expected: The "next month, same day" candidate lands on May 15, 2026, labeled with the
    /// full date.
    @Test func testNextMonthSameDayCandidateDateAndLabel() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let task = DataModel.Task(title: "Recurring-ish", period: nil, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)
        let sameDayOption = options.first { $0.kind == .nextMonthSameDay }

        #expect(sameDayOption != nil)
        #expect(sameDayOption?.date == makeDate(year: 2026, month: 5, day: 15))
        #expect(sameDayOption?.label == "May 15, 2026")
        #expect(sameDayOption?.period == .day)
    }

    /// Conditions: Evaluated on April 15, 2026.
    /// Expected: The "next month" candidate lands on May 1, 2026 (the 1st), labeled with the
    /// month and year only.
    @Test func testNextMonthCandidateDateAndLabel() {
        let today = makeDate(year: 2026, month: 4, day: 15)
        let task = DataModel.Task(title: "Punt to next month", period: nil, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)
        let nextMonthOption = options.first { $0.kind == .nextMonth }

        #expect(nextMonthOption != nil)
        #expect(nextMonthOption?.date == makeDate(year: 2026, month: 5, day: 1))
        #expect(nextMonthOption?.label == "May 2026")
        #expect(nextMonthOption?.period == .month)
    }

    /// Conditions: Evaluated on January 31, 2026 — next month (February) has no 31st.
    /// Expected: The "next month, same day" candidate is absent (no matching day-of-month
    /// exists in the target month), but the other three candidates are still present.
    @Test func testNextMonthSameDayOmittedWhenTargetMonthHasNoMatchingDay() {
        let today = makeDate(year: 2026, month: 1, day: 31)
        let task = DataModel.Task(title: "End of January", period: nil, status: .open)

        let options = task.migrationOptions(today: today, calendar: calendar)

        #expect(!options.map(\.kind).contains(.nextMonthSameDay))
        #expect(Set(options.map(\.kind)) == Set([.today, .tomorrow, .nextMonth]))
    }
}
