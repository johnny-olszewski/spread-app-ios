import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for the SPRD-315 `Entry.resolvedIconColor` status-icon tint rule. See
/// `Documentation/Specs/EventKit.md` — "Event Row Styling in Day-List Content".
struct EntryResolvedIconColorTests {

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

    private func makeTimedCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: "timed-1",
            title: "Design review",
            startDate: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            endDate: makeDate(year: 2026, month: 7, day: 10, hour: 10),
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: .blue
        )
    }

    // MARK: - Entries with a tint (events)

    /// Conditions: An upcoming (non-terminal) event with a calendar tint.
    /// Expected: `resolvedIconColor` is the entry's own tint, at full opacity.
    @Test func testUpcomingEventUsesFullCalendarTint() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            calendar: testCalendar
        )
        #expect(event.resolvedIconColor == event.iconColor)
    }

    /// Conditions: A passed (terminal, `.complete`) event with a calendar tint.
    /// Expected: `resolvedIconColor` is the entry's own tint, subdued (not the status gray).
    @Test func testPassedEventUsesSubduedCalendarTint() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 12),
            calendar: testCalendar
        )
        #expect(event.status == .complete)
        let resolved = event.resolvedIconColor
        #expect(resolved != event.status.iconColor)
        #expect(resolved != event.iconColor)
    }

    // MARK: - Entries with no tint (tasks, notes, stored events)

    /// Conditions: An open task (no `iconColor` override — falls back to the `Entry` default nil).
    /// Expected: `resolvedIconColor` falls back to the status color, matching pre-SPRD-315 behavior.
    @Test func testTaskWithNoTintFallsBackToStatusColor() {
        let task = DataModel.Task(title: "Buy groceries", status: .open)
        #expect(task.iconColor == nil)
        #expect(task.resolvedIconColor == task.status.iconColor)
    }

    /// Conditions: A cancelled (terminal) task with no `iconColor` override.
    /// Expected: `resolvedIconColor` is the status gray, same as before SPRD-315 — a nil
    /// entry tint never introduces a subdued color, it just falls through to status color.
    @Test func testCancelledTaskWithNoTintFallsBackToStatusColor() {
        let task = DataModel.Task(title: "Buy a boat", status: .cancelled)
        #expect(task.resolvedIconColor == task.status.iconColor)
    }

    /// Conditions: A stored (non-EventKit) event, which has no `calendarEvent` and thus no tint.
    /// Expected: `resolvedIconColor` falls back to the status color regardless of passed state.
    @Test func testStoredEventWithNoTintFallsBackToStatusColor() {
        let event = DataModel.Event(
            title: "Stored event",
            timing: .singleDay,
            startDate: makeDate(year: 2026, month: 7, day: 10),
            endDate: makeDate(year: 2026, month: 7, day: 10)
        )
        #expect(event.iconColor == nil)
        #expect(event.resolvedIconColor == event.status.iconColor)
    }
}
