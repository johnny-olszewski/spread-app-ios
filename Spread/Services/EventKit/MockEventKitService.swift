import Foundation

/// Mock EventKit service for localhost and testing.
///
/// Returns configurable stub events without accessing the device's EventKit.
@MainActor
final class MockEventKitService: EventKitService {

    // MARK: - Configuration

    /// Configurable authorization status returned by this mock.
    var stubbedStatus: EventAuthorizationStatus = .authorized

    /// Events returned for any date range query. Filtered by date range on fetch.
    var stubbedEvents: [CalendarEvent] = []

    /// Whether `requestAuthorization()` should grant access.
    var stubbedAuthorizationResult: Bool = true

    // MARK: - EventKitService

    var authorizationStatus: EventAuthorizationStatus { stubbedStatus }

    func requestAuthorization() async -> Bool {
        if stubbedAuthorizationResult {
            stubbedStatus = .authorized
        }
        return stubbedAuthorizationResult
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        guard authorizationStatus == .authorized else { return [] }
        return stubbedEvents.filter { event in
            event.startDate < end && event.endDate > start
        }
    }

    func openEvent(_ event: CalendarEvent) {
        // No-op for mock
    }
}
