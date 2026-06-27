import SwiftUI

private struct CalendarEventServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: any CalendarEventService = EmptyCalendarEventService()
}

extension EnvironmentValues {
    /// The app-wide service for fetching calendar events for a spread's date range.
    var calendarEventService: any CalendarEventService {
        get { self[CalendarEventServiceEnvironmentKey.self] }
        set { self[CalendarEventServiceEnvironmentKey.self] = newValue }
    }
}
