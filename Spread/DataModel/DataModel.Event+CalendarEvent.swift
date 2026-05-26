import SwiftUI

extension DataModel.Event {

    /// The icon color for this event. Non-nil only for ephemeral EventKit-backed events.
    var iconColor: Color? { calendarEvent?.calendarColor }

    /// Creates an ephemeral display-only event backed by an EventKit `CalendarEvent`.
    ///
    /// The resulting instance is never inserted into a SwiftData context.
    convenience init(calendarEvent: CalendarEvent) {
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
    }
}
