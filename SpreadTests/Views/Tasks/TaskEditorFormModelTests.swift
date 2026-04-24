import Foundation
import Testing
@testable import Spread

struct TaskEditorFormModelTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }

    /// Conditions: Create mode is initialized from a 2026 year spread while today is March 29, 2026.
    /// Expected: Switching the editor from year to day clamps the selected date to today's day instead of keeping January 1.
    @Test("Create-mode task editor clamps stale year dates when switching to day")
    func createModePeriodChangeClampsToCurrentDay() {
        let today = makeDate(year: 2026, month: 3, day: 29)
        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        var model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: yearSpread
        )

        model.setPeriod(.day)

        #expect(model.selectedDate == today)
    }

    /// Conditions: Edit mode opens a task preferred for 2026 on January 1 while today is March 29, 2026.
    /// Expected: Switching the editor from year to day clamps the selected date to today's day so edit-time reassignment matches create-time behavior.
    @Test("Edit-mode task editor uses the same day clamp as create mode")
    func editModePeriodChangeClampsToCurrentDay() {
        let today = makeDate(year: 2026, month: 3, day: 29)
        let task = DataModel.Task(
            title: "Navigator year task",
            date: makeDate(year: 2026, month: 1, day: 1),
            period: .year,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: today, status: .open)]
        )
        var model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            task: task
        )

        model.setPeriod(.day)

        #expect(model.selectedDate == today)
    }

    /// Conditions: Edit mode flips a year task to day but save reads the effective selection instead of trusting stale UI picker state.
    /// Expected: The effective date resolves to the current day for the new period.
    @Test("Edit-mode effective date matches the clamped day selection")
    func editModeEffectiveDateUsesAdjustedSelection() {
        let today = makeDate(year: 2026, month: 4, day: 6)
        let task = DataModel.Task(
            title: "Navigator year task",
            date: makeDate(year: 2026, month: 1, day: 1),
            period: .year,
            status: .open,
            assignments: [TaskAssignment(period: .year, date: makeDate(year: 2026, month: 1, day: 1), status: .open)]
        )
        var model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            task: task
        )

        model.setPeriod(.day)

        #expect(model.effectiveSelectedDate == today)
    }

    @Test("Create-mode task editor defaults assignment off outside a spread")
    func createModeDefaultsAssignmentOffWithoutSelectedSpread() {
        let today = makeDate(year: 2026, month: 4, day: 6)
        let model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: nil
        )

        #expect(model.hasPreferredAssignment == false)
        #expect(model.selectedPeriod == .day)
        #expect(model.selectedDate == today)
    }

    @Test("Create-mode task editor defaults assignment on from a selected spread")
    func createModeDefaultsAssignmentOnWithSelectedSpread() {
        let today = makeDate(year: 2026, month: 4, day: 6)
        let monthDate = makeDate(year: 2026, month: 4, day: 1)
        let spread = DataModel.Spread(period: .month, date: monthDate, calendar: calendar)
        let model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: spread
        )

        #expect(model.hasPreferredAssignment == true)
        #expect(model.selectedPeriod == .month)
        #expect(model.selectedDate == monthDate)
    }

    @Test("Edit-mode nil assignment turns assignment on at today day")
    func editModeNilAssignmentTurnsOnAtTodayDay() {
        let today = makeDate(year: 2026, month: 4, day: 6)
        let task = DataModel.Task(
            title: "Inbox",
            date: makeDate(year: 2026, month: 1, day: 1),
            period: .year,
            hasPreferredAssignment: false,
            status: .open
        )
        var model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            task: task
        )

        model.setPreferredAssignmentEnabled(true)

        #expect(model.hasPreferredAssignment == true)
        #expect(model.selectedPeriod == .day)
        #expect(model.selectedDate == today)
    }

    @Test("Task editor trims blank body to nil and due date to day")
    func taskEditorNormalizesBodyAndDueDate() {
        let today = makeDate(year: 2026, month: 4, day: 6)
        var model = TaskEditorFormModel(
            configuration: TaskCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: nil
        )
        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 15))!

        model.body = "  \n  "
        model.hasDueDate = true
        model.dueDate = dueDate

        #expect(model.sanitizedBody == nil)
        #expect(model.effectiveDueDate == makeDate(year: 2026, month: 5, day: 2))
    }
}
