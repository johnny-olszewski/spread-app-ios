import SwiftUI

private struct CalendarEventServiceEnvironmentKey: EnvironmentKey {

    /// Equatable wrapper that uses `ObjectIdentifier`-based identity comparison,
    /// allowing SwiftUI to short-circuit environment propagation when the same
    /// service instance is re-injected (e.g. on repeated `ContentView.body` evaluations
    /// caused by scene-phase changes or auth-state updates). Works correctly for
    /// class-backed conformers (`LiveCalendarEventService`, `MockCalendarEventService`);
    /// struct-backed conformers always compare as unequal, which is acceptable
    /// since only class instances are repeatedly re-injected in practice.
    struct Box: Equatable {
        let value: any CalendarEventService

        static func == (lhs: Self, rhs: Self) -> Bool {
            (lhs.value as AnyObject) === (rhs.value as AnyObject)
        }
    }

    static let defaultValue = Box(value: EmptyCalendarEventService())
}

extension EnvironmentValues {
    /// The app-wide service for fetching calendar events for a spread's date range.
    var calendarEventService: any CalendarEventService {
        get { self[CalendarEventServiceEnvironmentKey.self].value }
        set { self[CalendarEventServiceEnvironmentKey.self] = .init(value: newValue) }
    }
}
