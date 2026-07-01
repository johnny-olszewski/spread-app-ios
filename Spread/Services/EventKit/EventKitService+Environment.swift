import SwiftUI

private struct EventKitServiceEnvironmentKey: EnvironmentKey {

    /// Equatable wrapper that uses `ObjectIdentifier`-based identity comparison,
    /// allowing SwiftUI to short-circuit environment propagation when the same
    /// service instance is re-injected (e.g. on repeated `ContentView.body` evaluations
    /// caused by scene-phase changes or auth-state updates). Works correctly for
    /// class-backed conformers (`LiveEventKitService`, `MockEventKitService`);
    /// struct-backed conformers always compare as unequal, which is acceptable
    /// since only class instances are repeatedly re-injected in practice.
    struct Box: Equatable {
        let value: (any EventKitService)?

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs.value, rhs.value) {
            case (nil, nil): return true
            case (.some, nil), (nil, .some): return false
            case (let l?, let r?): return (l as AnyObject) === (r as AnyObject)
            }
        }
    }

    static let defaultValue = Box(value: nil)
}

extension EnvironmentValues {
    /// The app-wide EventKit service for fetching and opening calendar events.
    var eventKitService: (any EventKitService)? {
        get { self[EventKitServiceEnvironmentKey.self].value }
        set { self[EventKitServiceEnvironmentKey.self] = .init(value: newValue) }
    }
}
