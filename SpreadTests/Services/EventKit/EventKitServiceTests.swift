import Foundation
import SwiftUI
import Testing
@testable import Spread

@MainActor
struct EventKitServiceTests {

    // MARK: - MockEventKitService authorization

    /// Conditions: Mock service initialized with default `.authorized` status.
    /// Expected: `authorizationStatus` returns `.authorized`.
    @Test func testMockDefaultStatusIsAuthorized() {
        let service = MockEventKitService()
        #expect(service.authorizationStatus == .authorized)
    }

    /// Conditions: Mock service configured with `.denied` status.
    /// Expected: `authorizationStatus` returns `.denied`.
    @Test func testMockStatusReflectsConfiguredValue() {
        let service = MockEventKitService()
        service.stubbedStatus = .denied
        #expect(service.authorizationStatus == .denied)
    }

    /// Conditions: Mock service with `.notDetermined` status and authorization result `true`.
    /// Expected: `requestAuthorization()` returns `true` and status updates to `.authorized`.
    @Test func testMockRequestAuthorizationGrantsAccess() async {
        let service = MockEventKitService()
        service.stubbedStatus = .notDetermined
        service.stubbedAuthorizationResult = true

        let granted = await service.requestAuthorization()

        #expect(granted == true)
        #expect(service.authorizationStatus == .authorized)
    }

    /// Conditions: Mock service with `.notDetermined` status and authorization result `false`.
    /// Expected: `requestAuthorization()` returns `false` and status remains `.notDetermined`.
    @Test func testMockRequestAuthorizationDeniedLeavesStatus() async {
        let service = MockEventKitService()
        service.stubbedStatus = .notDetermined
        service.stubbedAuthorizationResult = false

        let granted = await service.requestAuthorization()

        #expect(granted == false)
        #expect(service.authorizationStatus == .notDetermined)
    }

    // MARK: - MockEventKitService fetchEvents

    /// Conditions: Authorized mock with one event overlapping the requested range.
    /// Expected: `fetchEvents` returns that event.
    @Test func testMockFetchEventsReturnsOverlappingEvents() {
        let service = MockEventKitService()
        let calendar = Calendar.current
        let today = Date()
        let start = today.startOfDay(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let event = CalendarEvent(
            id: "test-1",
            title: "Morning Standup",
            startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)!,
            endDate: calendar.date(bySettingHour: 9, minute: 30, second: 0, of: today)!,
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: .blue
        )
        service.stubbedEvents = [event]

        let results = service.fetchEvents(from: start, to: end)

        #expect(results.count == 1)
        #expect(results.first?.id == "test-1")
        #expect(results.first?.title == "Morning Standup")
    }

    /// Conditions: Authorized mock with an event entirely outside the requested range.
    /// Expected: `fetchEvents` returns no events.
    @Test func testMockFetchEventsExcludesNonOverlappingEvents() {
        let service = MockEventKitService()
        let calendar = Calendar.current
        let today = Date()
        let start = today.startOfDay(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let event = CalendarEvent(
            id: "test-future",
            title: "Tomorrow Event",
            startDate: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)!,
            endDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!,
            isAllDay: false,
            calendarTitle: "Personal",
            calendarColor: .green
        )
        service.stubbedEvents = [event]

        let results = service.fetchEvents(from: start, to: end)

        #expect(results.isEmpty)
    }

    /// Conditions: Mock with `.denied` status and stubbed events.
    /// Expected: `fetchEvents` returns no events regardless of stubs.
    @Test func testMockFetchEventsReturnsEmptyWhenDenied() {
        let service = MockEventKitService()
        service.stubbedStatus = .denied
        let calendar = Calendar.current
        let today = Date()
        let start = today.startOfDay(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        let event = CalendarEvent(
            id: "test-denied",
            title: "Some Event",
            startDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!,
            endDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: today)!,
            isAllDay: false,
            calendarTitle: "Personal",
            calendarColor: .red
        )
        service.stubbedEvents = [event]

        let results = service.fetchEvents(from: start, to: end)

        #expect(results.isEmpty)
    }

    /// Conditions: Mock with a multi-day event that spans the query range boundary.
    /// Expected: `fetchEvents` includes the event because it overlaps the range.
    @Test func testMockFetchEventsIncludesMultidayEventSpanningRange() {
        let service = MockEventKitService()
        let calendar = Calendar.current
        let today = Date()
        let start = today.startOfDay(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Event starts yesterday and ends tomorrow — spans today completely
        let event = CalendarEvent(
            id: "multi",
            title: "Conference",
            startDate: yesterday.startOfDay(calendar: calendar),
            endDate: tomorrow.startOfDay(calendar: calendar),
            isAllDay: true,
            calendarTitle: "Work",
            calendarColor: .orange
        )
        service.stubbedEvents = [event]

        let results = service.fetchEvents(from: start, to: end)

        #expect(results.count == 1)
        #expect(results.first?.id == "multi")
    }

    // MARK: - CalendarEvent day-overlap filtering

    /// Conditions: Helper logic for filtering events to a single day.
    /// Expected: Event starting before day-end and ending after day-start is included.
    @Test func testCalendarEventOverlapFilterIncludesOverlapping() {
        let calendar = Calendar.current
        let today = Date()
        let dayStart = today.startOfDay(calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let event = CalendarEvent(
            id: "overlap",
            title: "Overlapping Event",
            startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
            endDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: .blue
        )

        let overlaps = event.startDate < dayEnd && event.endDate > dayStart
        #expect(overlaps)
    }

    /// Conditions: All-day event where EventKit sets endDate to start of next day.
    /// Expected: Overlap filter correctly includes event for the all-day date.
    @Test func testCalendarEventOverlapFilterHandlesAllDayEndDate() {
        let calendar = Calendar.current
        let today = Date()
        let dayStart = today.startOfDay(calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        // All-day event: startDate = dayStart, endDate = dayEnd (EventKit convention)
        let event = CalendarEvent(
            id: "allday",
            title: "All Day Event",
            startDate: dayStart,
            endDate: dayEnd,
            isAllDay: true,
            calendarTitle: "Personal",
            calendarColor: .green
        )

        let overlaps = event.startDate < dayEnd && event.endDate > dayStart
        #expect(overlaps)
    }

    /// Conditions: All-day event on the previous day (endDate exactly equals today's start).
    /// Expected: Overlap filter excludes event from today's range.
    @Test func testCalendarEventOverlapFilterExcludesPreviousDayAllDay() {
        let calendar = Calendar.current
        let today = Date()
        let dayStart = today.startOfDay(calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Yesterday all-day: starts at yesterday 00:00, ends exactly at today 00:00
        let event = CalendarEvent(
            id: "yesterday",
            title: "Yesterday Event",
            startDate: yesterday.startOfDay(calendar: calendar),
            endDate: dayStart,
            isAllDay: true,
            calendarTitle: "Personal",
            calendarColor: .purple
        )

        let overlaps = event.startDate < dayEnd && event.endDate > dayStart
        #expect(!overlaps)
    }
}
