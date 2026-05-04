import SwiftUI

private struct EventKitServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue: (any EventKitService)? = nil
}

extension EnvironmentValues {
    /// The app-wide EventKit service for fetching and opening calendar events.
    var eventKitService: (any EventKitService)? {
        get { self[EventKitServiceEnvironmentKey.self] }
        set { self[EventKitServiceEnvironmentKey.self] = newValue }
    }
}
