import SwiftUI

extension DataModel.Event {

    /// Display-only status. Ephemeral EventKit-backed events stamped `hasPassed` render with
    /// the completed treatment (X overlay, gray title); everything else is upcoming. Events
    /// have no user-editable or persisted status. [SPRD-315]
    var status: EntryStatus { hasPassed ? .complete : .upcoming }

    /// Whether this event's time has fully passed as of `now`.
    ///
    /// Timed events end at their `endTime` instant. Date-only events (all-day,
    /// single-day, multi-day) end when the final calendar day of `endDate` is over —
    /// EventKit-backed all-day events already carry that boundary directly, since
    /// EventKit sets `endDate` to the start of the day after the final day (exclusive);
    /// stored events carry an inclusive final-day `endDate`, so the day boundary is derived.
    func hasEnded(at now: Date, calendar: Calendar) -> Bool {
        if let endTime {
            return endTime < now
        }
        if let calendarEvent, calendarEvent.isAllDay {
            return calendarEvent.endDate <= now
        }
        guard let dayAfterEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: endDate)
        ) else {
            return false
        }
        return dayAfterEnd <= now
    }
}
