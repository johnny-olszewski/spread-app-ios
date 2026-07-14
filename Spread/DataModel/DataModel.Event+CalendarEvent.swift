import SwiftUI

extension DataModel.Event {

    /// The icon color for this event. Non-nil only for ephemeral EventKit-backed events.
    var iconColor: Color? { calendarEvent?.calendarColor }

    /// Creates an ephemeral display-only event backed by an EventKit `CalendarEvent`.
    ///
    /// The resulting instance is never inserted into a SwiftData context. `hasPassed` is
    /// stamped once at construction from `now` — status re-evaluates at refresh moments
    /// because callers rebuild these wrappers per render, not via a timer. [SPRD-315]
    ///
    /// - Parameters:
    ///   - calendarEvent: The EventKit event to wrap.
    ///   - now: The current instant, from the caller's `AppClock`.
    ///   - calendar: The spread's calendar, used for the all-day day-boundary rule.
    convenience init(calendarEvent: CalendarEvent, asOf now: Date, calendar: Calendar) {
        let timing: EventTiming = calendarEvent.isAllDay ? .allDay : .timed
        self.init(
            title: calendarEvent.title,
            timing: timing,
            startDate: calendarEvent.startDate,
            endDate: calendarEvent.endDate,
            startTime: calendarEvent.isAllDay ? nil : calendarEvent.startDate,
            endTime: calendarEvent.isAllDay ? nil : calendarEvent.endDate
        )
        self.calendarEvent = calendarEvent
        self.hasPassed = hasEnded(at: now, calendar: calendar)
    }
}
