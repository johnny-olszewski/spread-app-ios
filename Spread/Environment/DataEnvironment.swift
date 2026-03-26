import Foundation

/// Represents the data target environment, separate from build configuration.
///
/// `DataEnvironment` determines where data lives and which backend services are used:
/// - `localhost`: Local-only mode. No Supabase, no auth, no sync.
/// - `development`: Supabase dev project. Auth and sync enabled.
/// - `production`: Supabase prod project. Auth and sync enabled.
///
/// Resolution order (via `resolve`):
/// 1. Launch arguments (`-DataEnvironment <value>`)
/// 2. Environment variables (`DATA_ENVIRONMENT`)
/// 3. Build default (from `BuildInfo.defaultDataEnvironment`)
enum DataEnvironment: String, CaseIterable, Sendable {
    case localhost
    case development
    case production

    // MARK: - Behavior Flags

    /// Whether this environment requires user authentication.
    var requiresAuth: Bool {
        switch self {
        case .localhost:
            return false
        case .development, .production:
            return true
        }
    }

    /// Whether sync with the backend is enabled.
    var syncEnabled: Bool {
        switch self {
        case .localhost:
            return false
        case .development, .production:
            return true
        }
    }

    /// Whether this environment operates in local-only mode (no backend).
    var isLocalOnly: Bool {
        self == .localhost
    }

    // MARK: - Display

    /// Human-readable label for UI display.
    var displayName: String {
        switch self {
        case .localhost:
            return "Local Only"
        case .development:
            return "Development"
        case .production:
            return "Production"
        }
    }

    // MARK: - Current Environment

    /// The current data environment, resolved from all available sources.
    static var current: DataEnvironment {
        resolve(
            launchArguments: ProcessInfo.processInfo.arguments,
            environmentVariables: ProcessInfo.processInfo.environment,
            buildDefault: BuildInfo.defaultDataEnvironment
        )
    }

    /// Resolves the data environment using a defined precedence order.
    ///
    /// - Parameters:
    ///   - launchArguments: Command-line arguments (e.g., from ProcessInfo).
    ///   - environmentVariables: Environment variables (e.g., from ProcessInfo).
    ///   - buildDefault: The default for the current build configuration.
    /// - Returns: The resolved data environment.
    static func resolve(
        launchArguments: [String],
        environmentVariables: [String: String],
        buildDefault: DataEnvironment
    ) -> DataEnvironment {
        // 1. Launch arguments
        if let index = launchArguments.firstIndex(of: "-DataEnvironment"),
           index + 1 < launchArguments.count,
           let env = DataEnvironment(rawValue: launchArguments[index + 1]) {
            return env
        }

        // 2. Environment variables
        if let value = environmentVariables["DATA_ENVIRONMENT"],
           let env = DataEnvironment(rawValue: value) {
            return env
        }

        // 3. Build default
        return buildDefault
    }

    // MARK: - Last Used Tracking

    private static let lastUsedKey = "DataEnvironment.lastUsed"

    /// The last data environment that was successfully used.
    ///
    /// Tracked across all builds to detect environment changes on launch.
    /// When the resolved environment differs from lastUsed, the local store
    /// should be wiped before creating the container.
    static var lastUsed: DataEnvironment? {
        guard let value = UserDefaults.standard.string(forKey: lastUsedKey) else {
            return nil
        }
        return DataEnvironment(rawValue: value)
    }

    /// Marks the given environment as the last successfully used.
    ///
    /// Call this after the container is created and before showing UI.
    static func markAsLastUsed(_ environment: DataEnvironment) {
        UserDefaults.standard.set(environment.rawValue, forKey: lastUsedKey)
    }

    /// Checks if a wipe is required on launch due to localhost isolation.
    ///
    /// - Parameter current: The resolved data environment for this launch.
    /// - Returns: `true` if the launch transitions to or from localhost.
    static func requiresWipeOnLaunch(current: DataEnvironment) -> Bool {
        guard let lastUsed else {
            // First launch or cleared - no wipe needed
            return false
        }
        guard lastUsed != current else {
            return false
        }
        return lastUsed == .localhost || current == .localhost
    }
}
