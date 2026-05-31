import Foundation

/// Mock `CalendarEventService` for tests and previews.
///
/// Returns a configurable array of `CalendarEvent` values without accessing EventKit.
@MainActor
final class MockCalendarEventService: CalendarEventService {

    /// The events returned by `fetchEvents(for:calendar:)`.
    var events: [CalendarEvent]

    init(events: [CalendarEvent] = []) {
        self.events = events
    }

    func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent] {
        events
    }
}
