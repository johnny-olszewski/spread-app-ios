import Foundation
import SwiftUI
import Testing
@testable import Spread

@MainActor
struct CalendarEventServiceTests {

    // MARK: - LiveCalendarEventService

    /// Conditions: EventKitService is not authorized (status is `.denied`).
    /// Expected: `fetchEvents` returns an empty array.
    @Test func testLiveServiceReturnsEmptyWhenNotAuthorized() async {
        let eventKitService = MockEventKitService()
        eventKitService.stubbedStatus = .denied
        let service = LiveCalendarEventService(eventKitService: eventKitService)
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)

        let events = await service.fetchEvents(for: spread, calendar: .current)

        #expect(events.isEmpty)
    }

    /// Conditions: EventKitService status is `.notDetermined`; `requestAuthorization()` returns `false`.
    /// Expected: `fetchEvents` requests authorization then returns an empty array.
    @Test func testLiveServiceRequestsAuthorizationWhenNotDetermined() async {
        let eventKitService = MockEventKitService()
        eventKitService.stubbedStatus = .notDetermined
        eventKitService.stubbedAuthorizationResult = false
        let service = LiveCalendarEventService(eventKitService: eventKitService)
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)

        let events = await service.fetchEvents(for: spread, calendar: .current)

        // Authorization was denied, so fetch should return nothing.
        #expect(events.isEmpty)
    }

    /// Conditions: EventKitService is authorized; stub returns an event overlapping today.
    /// Expected: `fetchEvents` returns the seeded event.
    @Test func testLiveServiceReturnsFetchedEventsWhenAuthorized() async {
        let eventKitService = MockEventKitService()
        eventKitService.stubbedStatus = .authorized
        let now = Date.now
        let stubEvent = CalendarEvent(
            id: "test-event",
            title: "Test Event",
            startDate: now,
            endDate: now.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Calendar",
            calendarColor: .blue
        )
        eventKitService.stubbedEvents = [stubEvent]
        let service = LiveCalendarEventService(eventKitService: eventKitService)
        let spread = DataModel.Spread(period: .day, date: now, calendar: .current)

        let events = await service.fetchEvents(for: spread, calendar: .current)

        #expect(events.count == 1)
        #expect(events.first?.id == "test-event")
    }

    // MARK: - MockCalendarEventService

    /// Conditions: `MockCalendarEventService` initialized with a seeded event array.
    /// Expected: `fetchEvents` returns the seeded array unchanged.
    @Test func testMockServiceReturnsSeededEvents() async {
        let stubEvent = CalendarEvent(
            id: "mock-event",
            title: "Mock Event",
            startDate: .now,
            endDate: .now.addingTimeInterval(3600),
            isAllDay: false,
            calendarTitle: "Work",
            calendarColor: .red
        )
        let service = MockCalendarEventService(events: [stubEvent])
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)

        let events = await service.fetchEvents(for: spread, calendar: .current)

        #expect(events.count == 1)
        #expect(events.first?.id == "mock-event")
    }

    /// Conditions: `MockCalendarEventService` initialized with no events (default).
    /// Expected: `fetchEvents` returns an empty array.
    @Test func testMockServiceDefaultsToEmpty() async {
        let service = MockCalendarEventService()
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)

        let events = await service.fetchEvents(for: spread, calendar: .current)

        #expect(events.isEmpty)
    }
}
