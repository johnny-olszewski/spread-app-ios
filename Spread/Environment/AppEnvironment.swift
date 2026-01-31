import Foundation

/// Represents the current execution environment of the app.
///
/// Use `AppEnvironment.current` to get the resolved environment based on:
/// 1. Launch arguments (`-AppEnvironment <value>`)
/// 2. Environment variables (`APP_ENVIRONMENT`)
/// 3. Build configuration (DEBUG vs Release)
enum AppEnvironment: String, CaseIterable {
    case production
    case development
    case preview
    case testing

    // MARK: - Current Environment

    /// The current app environment, resolved from launch arguments, environment variables, or build configuration.
    static var current: AppEnvironment {
        resolve(
            launchArguments: ProcessInfo.processInfo.arguments,
            environmentVariables: ProcessInfo.processInfo.environment,
            isDebugBuild: isDebugBuild
        )
    }

    /// Resolves the environment from the given parameters.
    ///
    /// Resolution order:
    /// 1. Launch arguments (`-AppEnvironment <value>`)
    /// 2. Environment variables (`APP_ENVIRONMENT`)
    /// 3. Build configuration (development for DEBUG, production for Release)
    static func resolve(
        launchArguments: [String],
        environmentVariables: [String: String],
        isDebugBuild: Bool
    ) -> AppEnvironment {
        // 1. Check launch arguments
        if let index = launchArguments.firstIndex(of: "-AppEnvironment"),
           index + 1 < launchArguments.count {
            let value = launchArguments[index + 1]
            if let environment = AppEnvironment(rawValue: value) {
                return environment
            }
        }

        // 2. Check environment variables
        if let value = environmentVariables["APP_ENVIRONMENT"],
           let environment = AppEnvironment(rawValue: value) {
            return environment
        }

        // 3. Default based on build configuration
        return isDebugBuild ? .development : .production
    }

    // MARK: - Configuration Properties

    /// Whether data should be stored in memory only (not persisted to disk).
    ///
    /// Returns `true` for preview and testing environments to ensure isolation.
    var isStoredInMemoryOnly: Bool {
        switch self {
        case .production, .development:
            return false
        case .preview, .testing:
            return true
        }
    }

    /// Whether mock data should be used instead of real data.
    ///
    /// Returns `true` only for preview environment.
    var usesMockData: Bool {
        switch self {
        case .production, .development, .testing:
            return false
        case .preview:
            return true
        }
    }

    /// The container name for SwiftData storage.
    ///
    /// Each environment has a unique container name to prevent data mixing.
    var containerName: String {
        switch self {
        case .production:
            return "Spread"
        case .development:
            return "Spread.development"
        case .preview:
            return "Spread.preview"
        case .testing:
            return "Spread.testing"
        }
    }

    // MARK: - Private

    private static var isDebugBuild: Bool {
        BuildInfo.allowsDebugUI
    }
}
