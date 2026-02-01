import Foundation

/// Centralizes build configuration gating for the app.
///
/// Use `BuildInfo` to determine what features and UI should be available
/// based on the current build configuration (Debug, QA, or Release).
enum BuildInfo {

    /// The human-readable name of the current build configuration.
    static var configurationName: String {
        #if DEBUG
        return isQABuild ? "QA" : "Debug"
        #else
        return "Release"
        #endif
    }

    /// Whether the current build allows debug UI (debug menu, environment switcher, etc.).
    ///
    /// Returns `true` for Debug and QA builds (both compile with the DEBUG flag).
    static var allowsDebugUI: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Whether the current build is a Release build.
    static var isRelease: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    /// The default data environment for the current build configuration.
    ///
    /// - Debug: localhost (local-only, no backend)
    /// - QA: development (Supabase dev project)
    /// - Release: production (Supabase prod project)
    static var defaultDataEnvironment: DataEnvironment {
        #if DEBUG
        return isQABuild ? .development : .localhost
        #else
        return .production
        #endif
    }

    // MARK: - Private

    /// Detects QA builds by checking the bundle identifier suffix.
    private static var isQABuild: Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".qa") ?? false
    }
}
