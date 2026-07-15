import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for the SPRD-302 passed-event display status: the `hasEnded(at:calendar:)`
/// predicate, the `hasPassed` stamp applied by `init(calendarEvent:asOf:calendar:)`,
/// and the `status` derivation. See `Documentation/Specs/EventKit.md` —
/// "Event Row Styling in Day-List Content".
struct EventPassedStatusTests {

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

    /// A timed EventKit event from 9:30–10:30 on July 10, 2026 (UTC).
    private func makeTimedCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: "timed-1",
            title: "Design review",
            startDate: makeDate(year: 2026, month: 7, day: 10, hour: 9, minute: 30),
            endDate: makeDate(year: 2026, month: 7, day: 10, hour: 10, minute: 30),
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: .blue
        )
    }

    /// An all-day EventKit event on July 10, 2026. EventKit's all-day convention:
    /// `endDate` is the start of the following day (exclusive boundary).
    private func makeAllDayCalendarEvent() -> CalendarEvent {
        CalendarEvent(
            id: "allday-1",
            title: "Holiday",
            startDate: makeDate(year: 2026, month: 7, day: 10),
            endDate: makeDate(year: 2026, month: 7, day: 11),
            isAllDay: true,
            calendarTitle: "Home",
            calendarColor: .green
        )
    }

    // MARK: - hasEnded: timed events

    /// Conditions: A timed event ending 10:30; `now` is 11:00 the same day.
    /// Expected: The event has ended — its end instant is earlier than now.
    @Test func testTimedEventPastEndTimeHasEnded() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 11),
            calendar: testCalendar
        )
        #expect(event.hasEnded(at: makeDate(year: 2026, month: 7, day: 10, hour: 11), calendar: testCalendar))
    }

    /// Conditions: A timed event running 9:30–10:30; `now` is 10:00 — in progress.
    /// Expected: The event has not ended; an in-progress event still renders as upcoming.
    @Test func testTimedEventInProgressHasNotEnded() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 10),
            calendar: testCalendar
        )
        #expect(!event.hasEnded(at: makeDate(year: 2026, month: 7, day: 10, hour: 10), calendar: testCalendar))
    }

    /// Conditions: A timed event starting 9:30; `now` is 8:00 the same day — upcoming.
    /// Expected: The event has not ended.
    @Test func testTimedEventUpcomingHasNotEnded() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 8),
            calendar: testCalendar
        )
        #expect(!event.hasEnded(at: makeDate(year: 2026, month: 7, day: 10, hour: 8), calendar: testCalendar))
    }

    // MARK: - hasEnded: all-day events

    /// Conditions: An all-day event on July 10; `now` is 23:59 on July 10 — the final
    /// day is not yet over.
    /// Expected: The event has not ended; all-day events stay upcoming through their final day.
    @Test func testAllDayEventOnItsDayHasNotEnded() {
        let now = makeDate(year: 2026, month: 7, day: 10, hour: 23, minute: 59)
        let event = DataModel.Event(calendarEvent: makeAllDayCalendarEvent(), asOf: now, calendar: testCalendar)
        #expect(!event.hasEnded(at: now, calendar: testCalendar))
    }

    /// Conditions: An all-day event on July 10; `now` is midnight July 11 — the exact
    /// exclusive EventKit end boundary (the whole final day is over).
    /// Expected: The event has ended as of the boundary instant.
    @Test func testAllDayEventEndsExactlyAtDayBoundary() {
        let boundary = makeDate(year: 2026, month: 7, day: 11)
        let event = DataModel.Event(calendarEvent: makeAllDayCalendarEvent(), asOf: boundary, calendar: testCalendar)
        #expect(event.hasEnded(at: boundary, calendar: testCalendar))
    }

    // MARK: - hasEnded: stored date-only events

    /// Conditions: A stored (non-EventKit) single-day event whose `endDate` is July 10
    /// itself — the inclusive stored convention, unlike EventKit's exclusive one.
    /// Expected: Not ended during July 10; ended once July 11 begins (day boundary derived
    /// by adding a day to the final `endDate` day).
    @Test func testStoredDateOnlyEventEndsAfterItsFinalDay() {
        let event = DataModel.Event(
            title: "Stored event",
            timing: .singleDay,
            startDate: makeDate(year: 2026, month: 7, day: 10),
            endDate: makeDate(year: 2026, month: 7, day: 10)
        )

        #expect(!event.hasEnded(at: makeDate(year: 2026, month: 7, day: 10, hour: 23, minute: 59), calendar: testCalendar))
        #expect(event.hasEnded(at: makeDate(year: 2026, month: 7, day: 11), calendar: testCalendar))
    }

    // MARK: - status stamping

    /// Conditions: A timed event constructed with `asOf` after its end time.
    /// Expected: `hasPassed` is stamped and `status` is `.complete` — the row renders
    /// with the completed-task treatment.
    @Test func testEventConstructedAfterEndIsComplete() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 12),
            calendar: testCalendar
        )
        #expect(event.hasPassed)
        #expect(event.status == .complete)
    }

    /// Conditions: A timed event constructed with `asOf` before its end time.
    /// Expected: `hasPassed` is false and `status` is `.upcoming`.
    @Test func testEventConstructedBeforeEndIsUpcoming() {
        let event = DataModel.Event(
            calendarEvent: makeTimedCalendarEvent(),
            asOf: makeDate(year: 2026, month: 7, day: 10, hour: 9),
            calendar: testCalendar
        )
        #expect(!event.hasPassed)
        #expect(event.status == .upcoming)
    }

    /// Conditions: A stored event created through the designated initializer — no
    /// EventKit backing, no stamp applied.
    /// Expected: `hasPassed` defaults to false and `status` stays `.upcoming` regardless
    /// of its dates; passed styling only ever applies via explicit construction-time stamping.
    @Test func testUnstampedStoredEventStaysUpcoming() {
        let event = DataModel.Event(
            title: "Old stored event",
            timing: .singleDay,
            startDate: makeDate(year: 2020, month: 1, day: 1),
            endDate: makeDate(year: 2020, month: 1, day: 1)
        )

        #expect(!event.hasPassed)
        #expect(event.status == .upcoming)
    }
}
