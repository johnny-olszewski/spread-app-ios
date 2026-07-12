import Foundation
import Testing
@testable import Spread

/// SPRD-299: scheduled-time chip state on `TaskEditorFormModel` — day-period gating, the
/// day+clock-time combination persisted on save, discard-on-selection-change, and edit-mode
/// prepopulation. See `Documentation/Specs/TaskScheduledTime.md`.
struct TaskEditorFormModelScheduledTimeTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeModel(today: Date) -> TaskEditorFormModel {
        TaskEditorFormModel(
            configuration: EntryCreationConfiguration(calendar: calendar, today: today),
            selectedSpread: nil
        )
    }

    // MARK: - Gating

    /// Conditions: Assignment selection walks through Inbox, day, month, year, and multiday.
    /// Expected: The time chip is available only for a day-period assignment.
    @Test("Scheduled time is only available for day-period assignments")
    func availabilityRequiresDayPeriod() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)

        #expect(!model.isScheduledTimeAvailable)

        model.setPreferredAssignmentEnabled(true)
        #expect(model.isScheduledTimeAvailable)

        for period in [Period.month, .year, .multiday] {
            model.setPeriod(period)
            #expect(!model.isScheduledTimeAvailable)
        }

        model.setPeriod(.day)
        #expect(model.isScheduledTimeAvailable)
    }

    /// Conditions: No time added, or the selection isn't day-period, or the task is headed
    /// to the Inbox.
    /// Expected: `effectiveScheduledTime` is nil in every case — nil is the sole "no time"
    /// signal persisted to the task.
    @Test("Effective scheduled time is nil without a day-period time selection")
    func effectiveTimeNilWhenUnavailable() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)

        #expect(model.effectiveScheduledTime == nil)

        model.setPreferredAssignmentEnabled(true)
        #expect(model.effectiveScheduledTime == nil)

        model.hasScheduledTime = true
        model.setPeriod(.month)
        #expect(model.effectiveScheduledTime == nil)
    }

    // MARK: - Save Combination

    /// Conditions: Day-period assignment on Jul 15 with a 15:30 clock time added.
    /// Expected: `effectiveScheduledTime` is the absolute instant Jul 15 15:30 in the
    /// configuration calendar — the assigned day combined with the picked clock time
    /// (the SPRD-296 "set" rule).
    @Test("Effective scheduled time combines assigned day with picked clock time")
    func effectiveTimeCombinesDayAndClockTime() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)
        model.setPreferredAssignmentEnabled(true)
        model.selectedDate = makeDate(year: 2026, month: 7, day: 15)
        model.hasScheduledTime = true
        model.scheduledTimeOfDay = makeDate(year: 2026, month: 1, day: 1, hour: 15, minute: 30)

        #expect(model.effectiveScheduledTime == makeDate(year: 2026, month: 7, day: 15, hour: 15, minute: 30))
    }

    // MARK: - Discard on Selection Change

    /// Conditions: A day-period time is added, then the period changes to month, then back
    /// to day.
    /// Expected: The pending time is discarded on leaving day — returning to day shows the
    /// chip in its empty state (`hasScheduledTime == false`).
    @Test("Changing period off day discards the pending time")
    func periodChangeDiscardsPendingTime() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)
        model.setPreferredAssignmentEnabled(true)
        model.hasScheduledTime = true

        model.setPeriod(.month)
        #expect(!model.hasScheduledTime)

        model.setPeriod(.day)
        #expect(!model.hasScheduledTime)
    }

    /// Conditions: A day-period time is added, then the assignment switches to Inbox.
    /// Expected: The pending time is discarded.
    @Test("Switching to Inbox discards the pending time")
    func inboxSwitchDiscardsPendingTime() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)
        model.setPreferredAssignmentEnabled(true)
        model.hasScheduledTime = true

        model.setPreferredAssignmentEnabled(false)
        #expect(!model.hasScheduledTime)
        #expect(model.effectiveScheduledTime == nil)
    }

    /// Conditions: A day-period time is added, then a multiday spread is applied via
    /// `applySpreadSelection` (the calendar-tap path that bypasses `setPeriod`).
    /// Expected: The pending time is discarded.
    @Test("Applying a non-day spread selection discards the pending time")
    func spreadSelectionDiscardsPendingTime() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        var model = makeModel(today: today)
        model.setPreferredAssignmentEnabled(true)
        model.hasScheduledTime = true

        model.applySpreadSelection(SpreadPickerSelection(
            period: .multiday,
            date: makeDate(year: 2026, month: 7, day: 12),
            spreadID: UUID()
        ))
        #expect(!model.hasScheduledTime)
    }

    // MARK: - Edit Prepopulation

    /// Conditions: Edit mode initializes from a task scheduled at Jul 15 09:45 on a day
    /// assignment.
    /// Expected: The chip shows as added with the stored clock time, and saving without
    /// changes round-trips the same instant.
    @Test("Edit mode prepopulates the chip from the task's scheduled time")
    func editModePrepopulatesFromTask() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        let scheduled = makeDate(year: 2026, month: 7, day: 15, hour: 9, minute: 45)
        let task = DataModel.Task(
            title: "Timed",
            scheduledTime: scheduled,
            date: makeDate(year: 2026, month: 7, day: 15),
            period: .day
        )

        let model = TaskEditorFormModel(
            configuration: EntryCreationConfiguration(calendar: calendar, today: today),
            task: task
        )

        #expect(model.hasScheduledTime)
        #expect(model.isScheduledTimeAvailable)
        #expect(model.effectiveScheduledTime == scheduled)
    }

    /// Conditions: Edit mode initializes from an untimed task.
    /// Expected: The chip shows in its empty state and `effectiveScheduledTime` is nil.
    @Test("Edit mode shows the empty chip for an untimed task")
    func editModeUntimedTask() {
        let today = makeDate(year: 2026, month: 7, day: 10)
        let task = DataModel.Task(
            title: "Untimed",
            date: makeDate(year: 2026, month: 7, day: 15),
            period: .day
        )

        let model = TaskEditorFormModel(
            configuration: EntryCreationConfiguration(calendar: calendar, today: today),
            task: task
        )

        #expect(!model.hasScheduledTime)
        #expect(model.effectiveScheduledTime == nil)
    }
}
