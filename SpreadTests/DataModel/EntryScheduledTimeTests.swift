import Foundation
import Testing
@testable import Spread

/// Tests for the SPRD-296 scheduled-time surface on `Entry`: the `isTimeAssignable`
/// capability flag and the `scheduledStart`/`scheduledEnd` accessors across all
/// three entry types. See `Documentation/Specs/TaskScheduledTime.md`.
struct EntryScheduledTimeTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return testCalendar.date(from: components)!
    }

    // MARK: - isTimeAssignable Capability Flag

    /// Conditions: Access the static per-type `isTimeAssignable` flag on each entry type.
    /// Expected: Only Task is time-assignable; Event carries its own times and Note has
    /// none — both fall back to the `false` default `Entry` implementation.
    @Test func testOnlyTaskIsTimeAssignable() {
        #expect(DataModel.Task().isTimeAssignable)
        #expect(!DataModel.Event().isTimeAssignable)
        #expect(!DataModel.Note().isTimeAssignable)
    }

    // MARK: - Task Accessors

    /// Conditions: A task with a `scheduledTime` set.
    /// Expected: `scheduledStart` returns the scheduled instant; `scheduledEnd` is nil
    /// (tasks are instantaneous — no duration in v1).
    @Test func testTaskWithTimeExposesScheduledStartAndNoEnd() {
        let scheduled = makeDate(year: 2026, month: 7, day: 10, hour: 15, minute: 30)
        let task = DataModel.Task(title: "Timed task", scheduledTime: scheduled)

        #expect(task.scheduledStart == scheduled)
        #expect(task.scheduledEnd == nil)
    }

    /// Conditions: A task with no `scheduledTime` (the default).
    /// Expected: Both accessors are nil — `nil` is the sole "no time" signal.
    @Test func testTaskWithoutTimeExposesNoScheduledTimes() {
        let task = DataModel.Task(title: "Untimed task")

        #expect(task.scheduledTime == nil)
        #expect(task.scheduledStart == nil)
        #expect(task.scheduledEnd == nil)
    }

    // MARK: - Event Accessors

    /// Conditions: A `.timed` event with start and end times.
    /// Expected: `scheduledStart`/`scheduledEnd` return `startTime`/`endTime`.
    @Test func testTimedEventExposesStartAndEndTimes() {
        let start = makeDate(year: 2026, month: 7, day: 10, hour: 9, minute: 0)
        let end = makeDate(year: 2026, month: 7, day: 10, hour: 10, minute: 30)
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: start,
            endDate: end,
            startTime: start,
            endTime: end
        )

        #expect(event.scheduledStart == start)
        #expect(event.scheduledEnd == end)
    }

    /// Conditions: An `.allDay` event and a `.singleDay` event (no specific times).
    /// Expected: Both accessors are nil — only `.timed` events are part of the
    /// time-integrated chronology.
    @Test func testAllDayAndSingleDayEventsExposeNoScheduledTimes() {
        let day = makeDate(year: 2026, month: 7, day: 10)
        let allDay = DataModel.Event(title: "Holiday", timing: .allDay, startDate: day, endDate: day)
        let singleDay = DataModel.Event(title: "Errand", timing: .singleDay, startDate: day, endDate: day)

        #expect(allDay.scheduledStart == nil)
        #expect(allDay.scheduledEnd == nil)
        #expect(singleDay.scheduledStart == nil)
        #expect(singleDay.scheduledEnd == nil)
    }

    // MARK: - Note Accessors

    /// Conditions: A note (notes never carry times).
    /// Expected: Both accessors are nil via the default `Entry` implementation.
    @Test func testNoteExposesNoScheduledTimes() {
        let note = DataModel.Note(title: "A note")

        #expect(note.scheduledStart == nil)
        #expect(note.scheduledEnd == nil)
    }

    // MARK: - Persistence Fields

    /// Conditions: A task created with `scheduledTime` and `scheduledTimeUpdatedAt`.
    /// Expected: Both persist through the initializer and default to nil when omitted,
    /// matching the `dueDate`/`dueDateUpdatedAt` template.
    @Test func testTaskScheduledTimeInitializerAndDefaults() {
        let scheduled = makeDate(year: 2026, month: 7, day: 10, hour: 8, minute: 0)
        let stamp = makeDate(year: 2026, month: 7, day: 9, hour: 12, minute: 0)
        let timed = DataModel.Task(scheduledTime: scheduled, scheduledTimeUpdatedAt: stamp)
        let untimed = DataModel.Task()

        #expect(timed.scheduledTime == scheduled)
        #expect(timed.scheduledTimeUpdatedAt == stamp)
        #expect(untimed.scheduledTime == nil)
        #expect(untimed.scheduledTimeUpdatedAt == nil)
    }
}
