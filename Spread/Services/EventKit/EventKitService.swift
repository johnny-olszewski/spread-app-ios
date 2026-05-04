import Foundation

/// Service for accessing EventKit calendar events.
///
/// Implementations:
/// - `LiveEventKitService`: Real EventKit access for production.
/// - `MockEventKitService`: Configurable stub for testing and localhost.
@MainActor
protocol EventKitService: Sendable {

    /// The current EventKit authorization status.
    var authorizationStatus: EventAuthorizationStatus { get }

    /// Requests full calendar access authorization.
    ///
    /// Triggers the system permission prompt when status is `notDetermined`.
    ///
    /// - Returns: `true` if authorization was granted.
    func requestAuthorization() async -> Bool

    /// Fetches events whose time span overlaps the given date range.
    ///
    /// Returns an empty array if not authorized. Results are sorted with
    /// all-day events first, then timed events ordered by start date.
    ///
    /// - Parameters:
    ///   - start: The inclusive start of the date range.
    ///   - end: The exclusive end of the date range.
    /// - Returns: Calendar events overlapping `[start, end)`.
    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent]

    /// Opens the given event for viewing.
    ///
    /// Presents an `EKEventViewController` when possible;
    /// falls back to opening the Calendar app at the event's date.
    func openEvent(_ event: CalendarEvent)
}
