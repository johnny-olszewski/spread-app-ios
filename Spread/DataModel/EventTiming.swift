/// The timing mode for an event.
///
/// Events can span single days or multiple days, and may have specific times.
enum EventTiming: String, CaseIterable, Codable, Sendable {
    /// A single-day event without specific times.
    case singleDay

    /// An all-day event on a single date.
    case allDay

    /// An event with specific start and end times on a single day.
    case timed

    /// An event spanning multiple days.
    case multiDay

    /// The human-readable display name for this timing mode.
    var displayName: String {
        switch self {
        case .singleDay: "Single Day"
        case .allDay: "All Day"
        case .timed: "Timed"
        case .multiDay: "Multi-Day"
        }
    }
}
