import Foundation
import Testing
@testable import Spread

struct EventPastStatusTests {

    // MARK: - Test Helpers

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "America/New_York")!
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    // MARK: - Timed Event Tests

    /// Conditions: Timed event where current time is before the end time.
    /// Expected: Event is not past.
    @Test func testTimedEventBeforeEndTimeIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            startTime: makeDate(year: 2026, month: 1, day: 16, hour: 10, minute: 0, calendar: calendar),
            endTime: makeDate(year: 2026, month: 1, day: 16, hour: 11, minute: 0, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 10, minute: 30, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Timed event where current time exceeds the end time.
    /// Expected: Event is past.
    @Test func testTimedEventAfterEndTimeIsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            startTime: makeDate(year: 2026, month: 1, day: 16, hour: 10, minute: 0, calendar: calendar),
            endTime: makeDate(year: 2026, month: 1, day: 16, hour: 11, minute: 0, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 11, minute: 30, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == true)
    }

    /// Conditions: Timed event where current time equals the end time exactly.
    /// Expected: Event is past (end time inclusive).
    @Test func testTimedEventAtExactEndTimeIsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            startTime: makeDate(year: 2026, month: 1, day: 16, hour: 10, minute: 0, calendar: calendar),
            endTime: makeDate(year: 2026, month: 1, day: 16, hour: 11, minute: 0, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 11, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == true)
    }

    // MARK: - All-Day Event Tests

    /// Conditions: All-day event on the current day.
    /// Expected: Event is not past.
    @Test func testAllDayEventOnCurrentDayIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Holiday",
            timing: .allDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 23, minute: 59, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: All-day event the day after the event date.
    /// Expected: Event is past.
    @Test func testAllDayEventOnNextDayIsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Holiday",
            timing: .allDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 0, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == true)
    }

    // MARK: - Single-Day Event Tests

    /// Conditions: Single-day event on the current day.
    /// Expected: Event is not past.
    @Test func testSingleDayEventOnCurrentDayIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Appointment",
            timing: .singleDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 14, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Single-day event the day after the event date.
    /// Expected: Event is past.
    @Test func testSingleDayEventOnNextDayIsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Appointment",
            timing: .singleDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 0, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == true)
    }

    // MARK: - Multi-Day Event Tests (Without Spread Context)

    /// Conditions: Multi-day event spanning Jan 16-18, current day is Jan 16 (first day).
    /// Expected: Event is not past (still in range).
    @Test func testMultiDayEventOnFirstDayIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 12, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Multi-day event spanning Jan 16-18, current day is Jan 17 (middle day).
    /// Expected: Event is not past (still in range).
    @Test func testMultiDayEventOnMiddleDayIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 12, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Multi-day event spanning Jan 16-18, current day is Jan 18 (last day).
    /// Expected: Event is not past (still in range).
    @Test func testMultiDayEventOnLastDayIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 18, hour: 23, minute: 59, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Multi-day event spanning Jan 16-18, current day is Jan 19 (day after).
    /// Expected: Event is past.
    @Test func testMultiDayEventAfterLastDayIsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 19, hour: 0, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == true)
    }

    // MARK: - Multi-Day Event Tests (With Spread Context)

    /// Conditions: Multi-day event spanning Jan 16-18, viewing on Jan 16 spread, current day is Jan 17.
    /// Expected: Event shows as past for the Jan 16 spread.
    @Test func testMultiDayEventOnPastSpreadDayShowsAsPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 12, minute: 0, calendar: calendar)
        let spreadDate = makeDate(year: 2026, month: 1, day: 16, calendar: calendar)

        let isPast = EventPastStatus.isPast(
            event: event,
            at: currentTime,
            forSpreadDate: spreadDate,
            calendar: calendar
        )

        #expect(isPast == true)
    }

    /// Conditions: Multi-day event spanning Jan 16-18, viewing on Jan 17 spread, current day is Jan 17.
    /// Expected: Event shows as current for the Jan 17 spread.
    @Test func testMultiDayEventOnCurrentSpreadDayShowsAsCurrent() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 12, minute: 0, calendar: calendar)
        let spreadDate = makeDate(year: 2026, month: 1, day: 17, calendar: calendar)

        let isPast = EventPastStatus.isPast(
            event: event,
            at: currentTime,
            forSpreadDate: spreadDate,
            calendar: calendar
        )

        #expect(isPast == false)
    }

    /// Conditions: Multi-day event spanning Jan 16-18, viewing on Jan 18 spread, current day is Jan 17.
    /// Expected: Event shows as current for the Jan 18 spread (future day within event range).
    @Test func testMultiDayEventOnFutureSpreadDayShowsAsCurrent() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Conference",
            timing: .multiDay,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 18, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 17, hour: 12, minute: 0, calendar: calendar)
        let spreadDate = makeDate(year: 2026, month: 1, day: 18, calendar: calendar)

        let isPast = EventPastStatus.isPast(
            event: event,
            at: currentTime,
            forSpreadDate: spreadDate,
            calendar: calendar
        )

        #expect(isPast == false)
    }

    // MARK: - Edge Cases

    /// Conditions: Timed event with nil endTime (should fall back to day-based logic).
    /// Expected: Uses end date for comparison.
    @Test func testTimedEventWithNilEndTimeUsesEndDate() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Meeting",
            timing: .timed,
            startDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            endDate: makeDate(year: 2026, month: 1, day: 16, calendar: calendar),
            startTime: makeDate(year: 2026, month: 1, day: 16, hour: 10, minute: 0, calendar: calendar),
            endTime: nil
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 23, minute: 59, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }

    /// Conditions: Event far in the future.
    /// Expected: Event is not past.
    @Test func testFutureEventIsNotPast() {
        let calendar = makeCalendar()
        let event = DataModel.Event(
            title: "Future Event",
            timing: .singleDay,
            startDate: makeDate(year: 2027, month: 6, day: 15, calendar: calendar),
            endDate: makeDate(year: 2027, month: 6, day: 15, calendar: calendar)
        )
        let currentTime = makeDate(year: 2026, month: 1, day: 16, hour: 12, minute: 0, calendar: calendar)

        let isPast = EventPastStatus.isPast(event: event, at: currentTime, calendar: calendar)

        #expect(isPast == false)
    }
}
