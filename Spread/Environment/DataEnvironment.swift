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
/// 3. Persisted selection (Debug/QA builds only)
/// 4. Build default (from `BuildInfo.defaultDataEnvironment`)
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
            persistedSelection: persistedSelection,
            allowsDebugUI: BuildInfo.allowsDebugUI,
            buildDefault: BuildInfo.defaultDataEnvironment
        )
    }

    /// Resolves the data environment using a defined precedence order.
    ///
    /// - Parameters:
    ///   - launchArguments: Command-line arguments (e.g., from ProcessInfo).
    ///   - environmentVariables: Environment variables (e.g., from ProcessInfo).
    ///   - persistedSelection: Previously persisted selection from UserDefaults.
    ///   - allowsDebugUI: Whether the current build allows debug features.
    ///   - buildDefault: The default for the current build configuration.
    /// - Returns: The resolved data environment.
    static func resolve(
        launchArguments: [String],
        environmentVariables: [String: String],
        persistedSelection: DataEnvironment?,
        allowsDebugUI: Bool,
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

        // 3. Persisted selection (Debug/QA only)
        if allowsDebugUI, let persisted = persistedSelection {
            return persisted
        }

        // 4. Build default
        return buildDefault
    }

    // MARK: - Persistence

    private static let persistenceKey = "DataEnvironment.selected"

    /// The persisted data environment selection from UserDefaults.
    /// Only used in Debug/QA builds.
    static var persistedSelection: DataEnvironment? {
        guard let value = UserDefaults.standard.string(forKey: persistenceKey) else {
            return nil
        }
        return DataEnvironment(rawValue: value)
    }

    /// Persists the selected data environment to UserDefaults.
    /// Should only be called in Debug/QA builds.
    static func persistSelection(_ environment: DataEnvironment) {
        UserDefaults.standard.set(environment.rawValue, forKey: persistenceKey)
    }

    /// Clears the persisted data environment selection.
    static func clearPersistedSelection() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }
}
