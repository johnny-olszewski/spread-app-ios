import Foundation

/// Utility for determining whether an event is past.
///
/// Provides static methods to compute past status based on event timing type
/// and optional spread context for multi-day events.
enum EventPastStatus {

    /// Determines whether an event is past at the given time.
    ///
    /// Past event rules:
    /// - **Timed events**: Past when current time exceeds end time.
    /// - **All-day/Single-day events**: Past starting the next day.
    /// - **Multi-day events**: Past when current time is after the last day.
    ///
    /// - Parameters:
    ///   - event: The event to check.
    ///   - currentTime: The current date and time.
    ///   - calendar: The calendar to use for date calculations.
    /// - Returns: `true` if the event is past.
    static func isPast(
        event: DataModel.Event,
        at currentTime: Date,
        calendar: Calendar
    ) -> Bool {
        switch event.timing {
        case .timed:
            return isTimedEventPast(event: event, at: currentTime, calendar: calendar)
        case .allDay, .singleDay:
            return isDayEventPast(event: event, at: currentTime, calendar: calendar)
        case .multiDay:
            return isMultiDayEventPast(event: event, at: currentTime, calendar: calendar)
        }
    }

    /// Determines whether an event is past for a specific spread date.
    ///
    /// This variant is used for multi-day events that span multiple day spreads.
    /// On a past day's spread, the event shows as past for that day only.
    ///
    /// - Parameters:
    ///   - event: The event to check.
    ///   - currentTime: The current date and time.
    ///   - spreadDate: The date of the spread being viewed.
    ///   - calendar: The calendar to use for date calculations.
    /// - Returns: `true` if the event is past for the given spread date.
    static func isPast(
        event: DataModel.Event,
        at currentTime: Date,
        forSpreadDate spreadDate: Date,
        calendar: Calendar
    ) -> Bool {
        let spreadStart = spreadDate.startOfDay(calendar: calendar)
        let currentDay = currentTime.startOfDay(calendar: calendar)

        // If the spread date is before today, the event appears as past on that spread
        return currentDay > spreadStart
    }

    // MARK: - Private Helpers

    /// Checks if a timed event is past.
    ///
    /// A timed event is past when the current time exceeds the end time.
    /// If endTime is nil, falls back to day-based logic.
    private static func isTimedEventPast(
        event: DataModel.Event,
        at currentTime: Date,
        calendar: Calendar
    ) -> Bool {
        guard let endTime = event.endTime else {
            // Fall back to day-based logic if no end time
            return isDayEventPast(event: event, at: currentTime, calendar: calendar)
        }
        return currentTime >= endTime
    }

    /// Checks if an all-day or single-day event is past.
    ///
    /// These events are past starting the next day after the end date.
    private static func isDayEventPast(
        event: DataModel.Event,
        at currentTime: Date,
        calendar: Calendar
    ) -> Bool {
        let currentDay = currentTime.startOfDay(calendar: calendar)
        let eventEndDay = event.endDate.startOfDay(calendar: calendar)

        // Past starting the next day
        return currentDay > eventEndDay
    }

    /// Checks if a multi-day event is past.
    ///
    /// A multi-day event is past when the current day is after the last day of the event.
    private static func isMultiDayEventPast(
        event: DataModel.Event,
        at currentTime: Date,
        calendar: Calendar
    ) -> Bool {
        let currentDay = currentTime.startOfDay(calendar: calendar)
        let eventEndDay = event.endDate.startOfDay(calendar: calendar)

        // Past starting the day after the last day
        return currentDay > eventEndDay
    }
}
