import Foundation
import SwiftUI

/// A calendar event fetched live from EventKit.
///
/// A pure value type — not a SwiftData model, not an Entry, not assignable.
/// Used only for display; fetched on demand and never persisted.
struct CalendarEvent: Identifiable, Sendable {
    /// The EventKit event identifier.
    let id: String
    /// The event title.
    let title: String
    /// The event start date.
    let startDate: Date
    /// The event end date.
    ///
    /// For all-day events, EventKit sets this to the start of the following day.
    let endDate: Date
    /// Whether the event spans all day.
    let isAllDay: Bool
    /// The name of the calendar this event belongs to.
    let calendarTitle: String
    /// The display color of the source calendar.
    let calendarColor: Color
}
