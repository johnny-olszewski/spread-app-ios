import Foundation

/// Fetches calendar events for a spread's date range.
///
/// Implementations:
/// - `LiveCalendarEventService`: Wraps `EventKitService` for production EventKit access.
/// - `MockCalendarEventService`: Returns configurable seeded events for tests and previews.
/// - `EmptyCalendarEventService`: Always returns `[]`; use where calendar events are not needed.
@MainActor
protocol CalendarEventService: Sendable {

    /// Fetches calendar events that overlap the date range of `spread`.
    ///
    /// - Parameters:
    ///   - spread: The spread whose date range determines which events are fetched.
    ///   - calendar: The calendar used to compute day boundaries.
    /// - Returns: Events overlapping the spread's date range, sorted all-day first then by start time.
    func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent]
}
