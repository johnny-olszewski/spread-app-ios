import Foundation

/// Centralizes build configuration gating for the app.
///
/// Use `BuildInfo` to determine what features and UI should be available
/// based on the current build configuration (Debug or Release).
enum BuildInfo {

    /// The human-readable name of the current build configuration.
    static var configurationName: String {
        buildConfiguration.displayName
    }

    /// Whether the current build allows debug UI (debug menu and engineering overrides).
    ///
    /// Returns `true` for Debug builds.
    static var allowsDebugUI: Bool {
        buildConfiguration != .release
    }

    /// Whether the current build is a Release build.
    static var isRelease: Bool {
        buildConfiguration == .release
    }

    /// The default data environment for the current build configuration.
    ///
    /// - Debug: localhost (local-only, no backend, unless overridden at launch)
    /// - Release: production (`spread-prod`)
    static var defaultDataEnvironment: DataEnvironment {
        switch buildConfiguration {
        case .debug:
            return .localhost
        case .release:
            return .production
        }
    }

    // MARK: - Private

    private enum BuildConfiguration: Equatable {
        case debug
        case release

        var displayName: String {
            switch self {
            case .debug:
                return "Debug"
            case .release:
                return "Release"
            }
        }
    }

    private static var buildConfiguration: BuildConfiguration {
        let bundleIdentifier = Bundle(for: BuildInfoBundleToken.self).bundleIdentifier ?? ""
        if bundleIdentifier.hasSuffix(".debug") {
            return .debug
        }
        return .release
    }

    private final class BuildInfoBundleToken {}
}
