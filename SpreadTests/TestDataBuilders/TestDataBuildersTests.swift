import Foundation
import Testing
@testable import Spread

struct TestDataBuildersTests {

    // MARK: - Fixed Reference Values

    /// Conditions: Access the fixed test date.
    /// Expected: Returns 2026-06-15 in UTC.
    @Test func testDateIsJune15_2026() {
        let calendar = TestDataBuilders.testCalendar
        let date = TestDataBuilders.testDate
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        #expect(components.year == 2026)
        #expect(components.month == 6)
        #expect(components.day == 15)
    }

    /// Conditions: Access the test calendar.
    /// Expected: Uses Gregorian identifier and UTC timezone.
    @Test func testCalendarIsGregorianUTC() {
        let calendar = TestDataBuilders.testCalendar

        #expect(calendar.identifier == .gregorian)
        #expect(calendar.timeZone == TimeZone(identifier: "UTC"))
    }

    /// Conditions: Call makeDate with specific components.
    /// Expected: Returns the correct date.
    @Test func makeDateReturnsCorrectDate() {
        let calendar = TestDataBuilders.testCalendar
        let date = TestDataBuilders.makeDate(year: 2026, month: 3, day: 10, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 10)
    }

    // MARK: - Spread Builders

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Returns 7 spreads covering year, month, day, multiday, and boundaries.
    @Test func spreadsReturnsSevenSpreads() {
        let spreadSet = TestDataBuilders.spreads()

        #expect(spreadSet.all.count == 7)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Year spread has period .year and date normalized to Jan 1.
    @Test func spreadsYearSpreadIsNormalizedToJanuary1() {
        let calendar = TestDataBuilders.testCalendar
        let spreadSet = TestDataBuilders.spreads()
        let components = calendar.dateComponents([.month, .day], from: spreadSet.year.date)

        #expect(spreadSet.year.period == .year)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Month spread has period .month and date normalized to 1st of June.
    @Test func spreadsMonthSpreadIsNormalizedToFirstOfMonth() {
        let calendar = TestDataBuilders.testCalendar
        let spreadSet = TestDataBuilders.spreads()
        let components = calendar.dateComponents([.month, .day], from: spreadSet.month.date)

        #expect(spreadSet.month.period == .month)
        #expect(components.month == 6)
        #expect(components.day == 1)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Day spread has period .day and date on June 15.
    @Test func spreadsDaySpreadIsOnTestDay() {
        let calendar = TestDataBuilders.testCalendar
        let spreadSet = TestDataBuilders.spreads()
        let components = calendar.dateComponents([.month, .day], from: spreadSet.day.date)

        #expect(spreadSet.day.period == .day)
        #expect(components.month == 6)
        #expect(components.day == 15)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Multiday spread has period .multiday with startDate and endDate set.
    @Test func spreadsMultidaySpreadHasDateRange() {
        let spreadSet = TestDataBuilders.spreads()

        #expect(spreadSet.multiday.period == .multiday)
        #expect(spreadSet.multiday.startDate != nil)
        #expect(spreadSet.multiday.endDate != nil)
        #expect(spreadSet.multiday.startDate! < spreadSet.multiday.endDate!)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Previous month spread is May, next month spread is July.
    @Test func spreadsBoundaryMonthsAreCorrect() {
        let calendar = TestDataBuilders.testCalendar
        let spreadSet = TestDataBuilders.spreads()
        let prevComponents = calendar.dateComponents([.month], from: spreadSet.previousMonth.date)
        let nextComponents = calendar.dateComponents([.month], from: spreadSet.nextMonth.date)

        #expect(prevComponents.month == 5)
        #expect(nextComponents.month == 7)
    }

    /// Conditions: Generate spreads with default parameters.
    /// Expected: Month-end spread is on June 30.
    @Test func spreadsMonthEndIsLastDayOfMonth() {
        let calendar = TestDataBuilders.testCalendar
        let spreadSet = TestDataBuilders.spreads()
        let components = calendar.dateComponents([.month, .day], from: spreadSet.monthEnd.date)

        #expect(spreadSet.monthEnd.period == .day)
        #expect(components.month == 6)
        #expect(components.day == 30)
    }

    /// Conditions: Generate spreads with a custom date in January.
    /// Expected: All spreads are relative to the custom date.
    @Test func spreadsWithCustomDateUsesCorrectMonth() {
        let calendar = TestDataBuilders.testCalendar
        let customDate = TestDataBuilders.makeDate(year: 2026, month: 1, day: 20, calendar: calendar)
        let spreadSet = TestDataBuilders.spreads(calendar: calendar, today: customDate)
        let monthComponents = calendar.dateComponents([.month], from: spreadSet.month.date)

        #expect(monthComponents.month == 1)
    }

    // MARK: - Task Builders

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Returns 6 tasks covering all status variants.
    @Test func tasksReturnsSixTasks() {
        let taskSet = TestDataBuilders.tasks()

        #expect(taskSet.all.count == 6)
    }

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Open-on-day task has one open assignment on the day period.
    @Test func tasksOpenOnDayHasCorrectAssignment() {
        let taskSet = TestDataBuilders.tasks()
        let task = taskSet.openOnDay

        #expect(task.status == .open)
        #expect(task.assignments.count == 1)
        #expect(task.assignments[0].period == .day)
        #expect(task.assignments[0].status == .open)
    }

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Migrated task has two assignments (source migrated, destination open).
    @Test func tasksMigratedHasTwoAssignments() {
        let taskSet = TestDataBuilders.tasks()
        let task = taskSet.migratedFromMonthToDay

        #expect(task.status == .open)
        #expect(task.assignments.count == 2)

        let monthAssignment = task.assignments.first { $0.period == .month }
        let dayAssignment = task.assignments.first { $0.period == .day }
        #expect(monthAssignment?.status == .migrated)
        #expect(dayAssignment?.status == .open)
    }

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Cancelled task has .cancelled status.
    @Test func tasksCancelledHasCancelledStatus() {
        let taskSet = TestDataBuilders.tasks()

        #expect(taskSet.cancelled.status == .cancelled)
    }

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Unassigned task has empty assignments array.
    @Test func tasksUnassignedHasNoAssignments() {
        let taskSet = TestDataBuilders.tasks()

        #expect(taskSet.unassigned.assignments.isEmpty)
    }

    /// Conditions: Generate tasks with default parameters.
    /// Expected: Task dates are normalized to the correct period start.
    @Test func tasksDateNormalizationIsCorrect() {
        let calendar = TestDataBuilders.testCalendar
        let today = TestDataBuilders.testDate
        let taskSet = TestDataBuilders.tasks()

        let yearDate = Period.year.normalizeDate(today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        #expect(calendar.isDate(taskSet.openOnYear.date, inSameDayAs: yearDate))
        #expect(calendar.isDate(taskSet.completedOnMonth.date, inSameDayAs: monthDate))
        #expect(calendar.isDate(taskSet.openOnDay.date, inSameDayAs: dayDate))
    }

    // MARK: - Note Builders

    /// Conditions: Generate notes with default parameters.
    /// Expected: Returns 5 notes covering status variants.
    @Test func notesReturnsFiveNotes() {
        let noteSet = TestDataBuilders.notes()

        #expect(noteSet.all.count == 5)
    }

    /// Conditions: Generate notes with default parameters.
    /// Expected: Active-on-day note has one active assignment.
    @Test func notesActiveOnDayHasCorrectAssignment() {
        let noteSet = TestDataBuilders.notes()
        let note = noteSet.activeOnDay

        #expect(note.status == .active)
        #expect(note.assignments.count == 1)
        #expect(note.assignments[0].period == .day)
        #expect(note.assignments[0].status == .active)
    }

    /// Conditions: Generate notes with default parameters.
    /// Expected: Migrated note has two assignments (source migrated, destination active).
    @Test func notesMigratedHasTwoAssignments() {
        let noteSet = TestDataBuilders.notes()
        let note = noteSet.migratedFromMonthToDay

        #expect(note.assignments.count == 2)

        let monthAssignment = note.assignments.first { $0.period == .month }
        let dayAssignment = note.assignments.first { $0.period == .day }
        #expect(monthAssignment?.status == .migrated)
        #expect(dayAssignment?.status == .active)
    }

    /// Conditions: Generate notes with default parameters.
    /// Expected: Note with content has non-empty content string.
    @Test func notesWithContentHasContent() {
        let noteSet = TestDataBuilders.notes()

        #expect(!noteSet.withContent.content.isEmpty)
    }

    /// Conditions: Generate notes with default parameters.
    /// Expected: Unassigned note has empty assignments array.
    @Test func notesUnassignedHasNoAssignments() {
        let noteSet = TestDataBuilders.notes()

        #expect(noteSet.unassigned.assignments.isEmpty)
    }

    // MARK: - Migration Chain Scenario

    /// Conditions: Generate migration chain setup.
    /// Expected: Task has 3 assignments (year→migrated, month→migrated, day→open).
    @Test func migrationChainTaskHasThreeAssignments() {
        let chain = TestDataBuilders.migrationChainSetup()

        #expect(chain.task.assignments.count == 3)

        let yearAssignment = chain.task.assignments.first { $0.period == .year }
        let monthAssignment = chain.task.assignments.first { $0.period == .month }
        let dayAssignment = chain.task.assignments.first { $0.period == .day }

        #expect(yearAssignment?.status == .migrated)
        #expect(monthAssignment?.status == .migrated)
        #expect(dayAssignment?.status == .open)
    }

    /// Conditions: Generate migration chain setup.
    /// Expected: Note has 2 assignments (month→migrated, day→active).
    @Test func migrationChainNoteHasTwoAssignments() {
        let chain = TestDataBuilders.migrationChainSetup()

        #expect(chain.note.assignments.count == 2)

        let monthAssignment = chain.note.assignments.first { $0.period == .month }
        let dayAssignment = chain.note.assignments.first { $0.period == .day }

        #expect(monthAssignment?.status == .migrated)
        #expect(dayAssignment?.status == .active)
    }

    /// Conditions: Generate migration chain setup.
    /// Expected: Three spreads cover year, month, and day periods.
    @Test func migrationChainHasThreeSpreads() {
        let chain = TestDataBuilders.migrationChainSetup()

        #expect(chain.allSpreads.count == 3)
        #expect(chain.yearSpread.period == .year)
        #expect(chain.monthSpread.period == .month)
        #expect(chain.daySpread.period == .day)
    }

    // MARK: - Batch Migration Scenario

    /// Conditions: Generate batch migration setup.
    /// Expected: Returns 3 tasks and 2 notes, all assigned to the source spread.
    @Test func batchMigrationHasCorrectCounts() {
        let batch = TestDataBuilders.batchMigrationSetup()

        #expect(batch.tasks.count == 3)
        #expect(batch.notes.count == 2)
    }

    /// Conditions: Generate batch migration setup.
    /// Expected: All tasks are open with one assignment on the source period.
    @Test func batchMigrationTasksAreOpenOnSource() {
        let batch = TestDataBuilders.batchMigrationSetup()

        for task in batch.tasks {
            #expect(task.status == .open)
            #expect(task.assignments.count == 1)
            #expect(task.assignments[0].period == batch.sourceSpread.period)
        }
    }

    /// Conditions: Generate batch migration setup.
    /// Expected: Source and destination spreads are different periods.
    @Test func batchMigrationSourceAndDestinationDiffer() {
        let batch = TestDataBuilders.batchMigrationSetup()

        #expect(batch.sourceSpread.period == .month)
        #expect(batch.destinationSpread.period == .day)
    }

    // MARK: - Spread Deletion Scenario

    /// Conditions: Generate spread deletion setup.
    /// Expected: Target spread has 2 tasks and 1 note assigned.
    @Test func spreadDeletionTargetHasCorrectEntries() {
        let deletion = TestDataBuilders.spreadDeletionSetup()

        #expect(deletion.tasksOnTarget.count == 2)
        #expect(deletion.notesOnTarget.count == 1)
    }

    /// Conditions: Generate spread deletion setup.
    /// Expected: Sibling task is assigned to the sibling spread, not the target.
    @Test func spreadDeletionSiblingTaskIsOnSibling() {
        let deletion = TestDataBuilders.spreadDeletionSetup()

        #expect(deletion.taskOnSibling.assignments[0].period == deletion.siblingSpread.period)
        #expect(deletion.taskOnSibling.assignments[0].period != deletion.targetSpread.period)
    }

    // MARK: - Boundary Scenario

    /// Conditions: Generate boundary setup.
    /// Expected: Dec 31 and Jan 1 spreads cross the year boundary.
    @Test func boundarySetupCrossesYearBoundary() {
        let calendar = TestDataBuilders.testCalendar
        let boundary = TestDataBuilders.boundarySetup()

        let dec31Components = calendar.dateComponents([.month, .day], from: boundary.lastDayOfYear.date)
        let jan1Components = calendar.dateComponents([.month, .day], from: boundary.firstDayOfNextYear.date)

        #expect(dec31Components.month == 12)
        #expect(dec31Components.day == 31)
        #expect(jan1Components.month == 1)
        #expect(jan1Components.day == 1)
    }

    /// Conditions: Generate boundary setup.
    /// Expected: Year spreads are for consecutive years.
    @Test func boundarySetupHasConsecutiveYears() {
        let calendar = TestDataBuilders.testCalendar
        let boundary = TestDataBuilders.boundarySetup()

        let currentYearComponent = calendar.component(.year, from: boundary.currentYear.date)
        let nextYearComponent = calendar.component(.year, from: boundary.nextYear.date)

        #expect(nextYearComponent == currentYearComponent + 1)
    }

    /// Conditions: Generate boundary setup.
    /// Expected: Cross-year multiday spread spans from Dec 30 to Jan 2.
    @Test func boundarySetupMultidaySpansYearBoundary() {
        let calendar = TestDataBuilders.testCalendar
        let boundary = TestDataBuilders.boundarySetup()

        let startComponents = calendar.dateComponents(
            [.month, .day],
            from: boundary.crossYearMultiday.startDate!
        )
        let endComponents = calendar.dateComponents(
            [.month, .day],
            from: boundary.crossYearMultiday.endDate!
        )

        #expect(startComponents.month == 12)
        #expect(startComponents.day == 30)
        #expect(endComponents.month == 1)
        #expect(endComponents.day == 2)
    }

    /// Conditions: Generate boundary setup.
    /// Expected: Task on last day is assigned to Dec 31.
    @Test func boundarySetupTaskIsOnDec31() {
        let calendar = TestDataBuilders.testCalendar
        let boundary = TestDataBuilders.boundarySetup()
        let components = calendar.dateComponents([.month, .day], from: boundary.taskOnLastDay.date)

        #expect(components.month == 12)
        #expect(components.day == 31)
        #expect(boundary.taskOnLastDay.status == .open)
    }

    // MARK: - Leap Day Scenario

    /// Conditions: Generate leap day setup with default leap year (2028).
    /// Expected: Feb 29 day spread is on Feb 29 of a leap year.
    @Test func leapDaySetupFeb29IsOnLeapDay() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()
        let components = calendar.dateComponents([.year, .month, .day], from: leapDay.feb29.date)

        #expect(components.year == 2028)
        #expect(components.month == 2)
        #expect(components.day == 29)
        #expect(leapDay.feb29.period == .day)
    }

    /// Conditions: Generate leap day setup.
    /// Expected: Feb 28 and Mar 1 day spreads bracket the leap day.
    @Test func leapDaySetupHasAdjacentDays() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()

        let feb28 = calendar.dateComponents([.month, .day], from: leapDay.feb28.date)
        let mar1 = calendar.dateComponents([.month, .day], from: leapDay.mar1.date)

        #expect(feb28.month == 2)
        #expect(feb28.day == 28)
        #expect(mar1.month == 3)
        #expect(mar1.day == 1)
    }

    /// Conditions: Generate leap day setup.
    /// Expected: February month spread is normalized to Feb 1 of the leap year.
    @Test func leapDaySetupFebruaryMonthSpreadIsNormalized() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()
        let components = calendar.dateComponents([.year, .month, .day], from: leapDay.february.date)

        #expect(leapDay.february.period == .month)
        #expect(components.year == 2028)
        #expect(components.month == 2)
        #expect(components.day == 1)
    }

    /// Conditions: Generate leap day setup.
    /// Expected: Multiday spread spans Feb 28 – Mar 1.
    @Test func leapDaySetupMultidaySpansTransition() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()

        #expect(leapDay.crossLeapDayMultiday.period == .multiday)

        let startComponents = calendar.dateComponents(
            [.month, .day],
            from: leapDay.crossLeapDayMultiday.startDate!
        )
        let endComponents = calendar.dateComponents(
            [.month, .day],
            from: leapDay.crossLeapDayMultiday.endDate!
        )

        #expect(startComponents.month == 2)
        #expect(startComponents.day == 28)
        #expect(endComponents.month == 3)
        #expect(endComponents.day == 1)
    }

    /// Conditions: Generate leap day setup.
    /// Expected: Task assigned to Feb 29 has correct date and open status.
    @Test func leapDaySetupTaskIsOnFeb29() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()
        let components = calendar.dateComponents([.month, .day], from: leapDay.taskOnLeapDay.date)

        #expect(components.month == 2)
        #expect(components.day == 29)
        #expect(leapDay.taskOnLeapDay.status == .open)
        #expect(leapDay.taskOnLeapDay.assignments.count == 1)
        #expect(leapDay.taskOnLeapDay.assignments[0].period == .day)
    }

    /// Conditions: Generate leap day setup.
    /// Expected: Note assigned to Feb 29 has correct date and active status.
    @Test func leapDaySetupNoteIsOnFeb29() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup()
        let components = calendar.dateComponents([.month, .day], from: leapDay.noteOnLeapDay.date)

        #expect(components.month == 2)
        #expect(components.day == 29)
        #expect(leapDay.noteOnLeapDay.status == .active)
        #expect(leapDay.noteOnLeapDay.assignments.count == 1)
    }

    /// Conditions: Generate leap day setup with all spreads.
    /// Expected: Returns 5 spreads (feb28, feb29, mar1, february, multiday).
    @Test func leapDaySetupHasFiveSpreads() {
        let leapDay = TestDataBuilders.leapDaySetup()

        #expect(leapDay.allSpreads.count == 5)
    }

    /// Conditions: Generate leap day setup with custom leap year.
    /// Expected: Dates use the specified leap year.
    @Test func leapDaySetupWithCustomLeapYear() {
        let calendar = TestDataBuilders.testCalendar
        let leapDay = TestDataBuilders.leapDaySetup(leapYear: 2032)
        let components = calendar.dateComponents([.year], from: leapDay.feb29.date)

        #expect(leapDay.leapYear == 2032)
        #expect(components.year == 2032)
    }

    /// Conditions: Date normalization on Feb 29.
    /// Expected: normalizeDate for .day returns Feb 29 unchanged (start of day).
    @Test func dateNormalizationOnFeb29PreservesDay() {
        let calendar = TestDataBuilders.testCalendar
        let feb29 = TestDataBuilders.makeDate(year: 2028, month: 2, day: 29, calendar: calendar)
        let normalized = Period.day.normalizeDate(feb29, calendar: calendar)
        let components = calendar.dateComponents([.month, .day], from: normalized)

        #expect(components.month == 2)
        #expect(components.day == 29)
    }

    /// Conditions: Date normalization on Feb 29 for month period.
    /// Expected: normalizeDate for .month returns Feb 1.
    @Test func dateNormalizationOnFeb29ForMonthReturnsFeb1() {
        let calendar = TestDataBuilders.testCalendar
        let feb29 = TestDataBuilders.makeDate(year: 2028, month: 2, day: 29, calendar: calendar)
        let normalized = Period.month.normalizeDate(feb29, calendar: calendar)
        let components = calendar.dateComponents([.month, .day], from: normalized)

        #expect(components.month == 2)
        #expect(components.day == 1)
    }
}
