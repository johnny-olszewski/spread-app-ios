import SwiftUI

private struct AppClockEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppClock? = nil
}

extension EnvironmentValues {
    var appClock: AppClock? {
        get { self[AppClockEnvironmentKey.self] }
        set { self[AppClockEnvironmentKey.self] = newValue }
    }
}
