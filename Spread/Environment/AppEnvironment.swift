import Foundation

/// Represents the execution context of the app.
///
/// `AppEnvironment` controls app lifecycle concerns: storage mode, mock data, and container naming.
/// Data targeting (localhost/dev/prod) is handled separately by `DataEnvironment`.
///
/// Resolution order for `AppEnvironment.current`:
/// 1. Launch arguments (`-AppEnvironment <value>`)
/// 2. Environment variables (`APP_ENVIRONMENT`)
/// 3. Default: `.live`
enum AppEnvironment: String, CaseIterable {
    case live
    case preview
    case testing

    // MARK: - Current Environment

    /// The current app environment, resolved from launch arguments, environment variables, or default.
    static var current: AppEnvironment {
        resolve(
            launchArguments: ProcessInfo.processInfo.arguments,
            environmentVariables: ProcessInfo.processInfo.environment
        )
    }

    /// Resolves the environment from the given parameters.
    ///
    /// Resolution order:
    /// 1. Launch arguments (`-AppEnvironment <value>`)
    /// 2. Environment variables (`APP_ENVIRONMENT`)
    /// 3. Default: `.live`
    static func resolve(
        launchArguments: [String],
        environmentVariables: [String: String]
    ) -> AppEnvironment {
        // 1. Check launch arguments
        if let index = launchArguments.firstIndex(of: "-AppEnvironment"),
           index + 1 < launchArguments.count,
           let environment = AppEnvironment(rawValue: launchArguments[index + 1]) {
            return environment
        }

        // 2. Check environment variables
        if let value = environmentVariables["APP_ENVIRONMENT"],
           let environment = AppEnvironment(rawValue: value) {
            return environment
        }

        // 3. Default
        return .live
    }

    // MARK: - Configuration Properties

    /// Whether data should be stored in memory only (not persisted to disk).
    ///
    /// Returns `true` for preview and testing environments to ensure isolation.
    var isStoredInMemoryOnly: Bool {
        switch self {
        case .live:
            return false
        case .preview, .testing:
            return true
        }
    }

    /// Whether mock data should be used instead of real data.
    ///
    /// Returns `true` only for preview environment.
    var usesMockData: Bool {
        self == .preview
    }

    /// The container name for SwiftData storage.
    var containerName: String {
        switch self {
        case .live:
            return "Spread"
        case .preview:
            return "Spread.preview"
        case .testing:
            return "Spread.testing"
        }
    }
}
