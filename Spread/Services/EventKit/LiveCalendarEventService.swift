import Foundation

/// Production `CalendarEventService` that fetches events from EventKit.
///
/// Handles authorization automatically: requests access when status is `.notDetermined`
/// and returns `[]` when not `.authorized`. Delegates the date-range query to the
/// injected `EventKitService`.
///
/// Supports both day spreads (uses `spread.date`) and multiday spreads
/// (uses `spread.startDate`/`spread.endDate` when present).
///
/// Declared as a `final class` (not `struct`) so that environment injection via
/// `CalendarEventServiceEnvironmentKey.Box` can use `ObjectIdentifier`-based identity
/// comparison (`===`) to detect when the same instance is re-injected, preventing
/// spurious SwiftUI re-renders on every `ContentView.body` evaluation.
@MainActor
final class LiveCalendarEventService: CalendarEventService {

    private let eventKitService: any EventKitService

    init(eventKitService: any EventKitService) {
        self.eventKitService = eventKitService
    }

    func fetchEvents(for spread: DataModel.Spread, calendar: Calendar) async -> [CalendarEvent] {
        if eventKitService.authorizationStatus == .notDetermined {
            _ = await eventKitService.requestAuthorization()
        }
        guard eventKitService.authorizationStatus == .authorized else { return [] }

        let rangeStart: Date
        let rangeEnd: Date

        if let startDate = spread.startDate, let endDate = spread.endDate {
            // Multiday spread: fetch across the full range.
            rangeStart = startDate.startOfDay(calendar: calendar)
            guard let end = calendar.date(
                byAdding: .day,
                value: 1,
                to: endDate.startOfDay(calendar: calendar)
            ) else { return [] }
            rangeEnd = end
        } else {
            // Day (or other single-date) spread: fetch for the one day.
            rangeStart = spread.date.startOfDay(calendar: calendar)
            guard let end = calendar.date(byAdding: .day, value: 1, to: rangeStart) else { return [] }
            rangeEnd = end
        }

        return eventKitService.fetchEvents(from: rangeStart, to: rangeEnd)
    }
}
