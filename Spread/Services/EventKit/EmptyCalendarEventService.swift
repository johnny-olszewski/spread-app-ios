import Foundation

/// No-op `CalendarEventService` that always returns an empty event list.
///
/// Use as a default where calendar events are not needed (e.g. unit test scaffolding).
@MainActor
struct EmptyCalendarEventService: CalendarEventService {
    func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent] { [] }
}
