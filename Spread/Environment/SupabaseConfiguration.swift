import Foundation

/// Configuration for connecting to Supabase backend services.
///
/// Values are read from Info.plist at runtime, which are populated from
/// xcconfig files at build time:
/// - Debug builds use `Configuration/Debug.xcconfig` (dev environment)
/// - Release builds use `Configuration/Release.xcconfig` (prod environment)
///
/// Debug builds can switch environments at runtime via the Debug menu (SPRD-86).
/// All builds can override URL/key at runtime via launch arguments or environment variables.
enum SupabaseConfiguration {

    /// The Supabase environment (development or production).
    enum Environment: String {
        case development
        case production
    }

    // MARK: - Build-time Configuration (from Info.plist)

    /// The Supabase project URL from build configuration.
    static var buildURL: URL {
        guard let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not configured in Info.plist. Ensure xcconfig is set up correctly.")
        }
        return url
    }

    /// The Supabase publishable key from build configuration.
    static var buildPublishableKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_PUBLISHABLE_KEY not configured in Info.plist. Ensure xcconfig is set up correctly.")
        }
        return key
    }

    /// The Supabase environment from build configuration.
    static var buildEnvironment: Environment {
        guard let envString = Bundle.main.infoDictionary?["SUPABASE_ENVIRONMENT"] as? String,
              let env = Environment(rawValue: envString) else {
            // Default to development if not set
            return .development
        }
        return env
    }

    // MARK: - Runtime Configuration

    /// The active Supabase URL to use.
    ///
    /// In Debug builds, this can be overridden via the Debug menu (SPRD-86).
    /// In any build, launch arguments or environment variables can provide explicit URL/key overrides.
    static var url: URL {
        #if DEBUG
        return runtimeOverrideURL ?? explicitRuntimeOverride?.url ?? buildURL
        #else
        return explicitRuntimeOverride?.url ?? buildURL
        #endif
    }

    /// The active Supabase publishable key to use.
    ///
    /// In Debug builds, this can be overridden via the Debug menu (SPRD-86).
    /// In any build, launch arguments or environment variables can provide explicit URL/key overrides.
    static var publishableKey: String {
        #if DEBUG
        return runtimeOverridePublishableKey ?? explicitRuntimeOverride?.key ?? buildPublishableKey
        #else
        return explicitRuntimeOverride?.key ?? buildPublishableKey
        #endif
    }

    /// The active Supabase environment.
    ///
    /// In Debug builds, this can be overridden via the Debug menu (SPRD-86).
    /// In Release builds, this always returns the build-time configuration.
    static var environment: Environment {
        #if DEBUG
        return runtimeOverrideEnvironment ?? buildEnvironment
        #else
        return buildEnvironment
        #endif
    }

    /// Whether the current configuration is pointing to production.
    static var isProduction: Bool {
        environment == .production
    }

    // MARK: - Debug Runtime Overrides

    #if DEBUG
    /// Runtime override for Supabase URL (Debug builds only).
    /// Set via Debug menu (SPRD-86).
    static var runtimeOverrideURL: URL?

    /// Runtime override for Supabase publishable key (Debug builds only).
    /// Set via Debug menu (SPRD-86).
    static var runtimeOverridePublishableKey: String?

    /// Runtime override for Supabase environment (Debug builds only).
    /// Set via Debug menu (SPRD-86).
    static var runtimeOverrideEnvironment: Environment?

    /// Clears all runtime overrides, reverting to build-time configuration.
    static func clearRuntimeOverrides() {
        runtimeOverrideURL = nil
        runtimeOverridePublishableKey = nil
        runtimeOverrideEnvironment = nil
    }

    /// Sets runtime overrides to use the development environment.
    static func useDevEnvironment() {
        runtimeOverrideURL = URL(string: "https://apblzzondjcughtgqowd.supabase.co")
        runtimeOverridePublishableKey = "sb_publishable_G74Nb3IoMfnsmrZfp6dcaA_0_UD6QLT"
        runtimeOverrideEnvironment = .development
    }

    /// Sets runtime overrides to use the production environment.
    static func useProdEnvironment() {
        runtimeOverrideURL = URL(string: "https://nzsswqmxodkvgsnabnaj.supabase.co")
        runtimeOverridePublishableKey = "sb_publishable_NSgP9CI8D3Ab3d4QmQ9Lwg_RV2tArlj"
        runtimeOverrideEnvironment = .production
    }
    #endif

    // MARK: - Launch Argument & Environment Overrides

    private enum OverrideSource: String {
        case launchArguments = "Launch Arguments"
        case environmentVariables = "Environment Variables"
    }

    /// Returns an explicit URL/key override when both values are supplied.
    private static var explicitRuntimeOverride: (url: URL, key: String, source: OverrideSource)? {
        if let urlString = launchArgumentValue(named: "-SupabaseURL"),
           let key = launchArgumentValue(named: "-SupabaseKey"),
           let url = URL(string: urlString),
           !key.isEmpty {
            return (url, key, .launchArguments)
        }

        let environment = ProcessInfo.processInfo.environment
        if let urlString = environment["SUPABASE_URL"],
           let key = environment["SUPABASE_PUBLISHABLE_KEY"],
           let url = URL(string: urlString),
           !key.isEmpty {
            return (url, key, .environmentVariables)
        }

        return nil
    }

    /// Describes the explicit override source when present.
    static var explicitOverrideSourceDescription: String? {
        explicitRuntimeOverride?.source.rawValue
    }

    private static func launchArgumentValue(named name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name),
              index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }

    #if DEBUG
    /// Describes the active debug override when set.
    static var runtimeOverrideDescription: String? {
        guard runtimeOverrideURL != nil ||
              runtimeOverridePublishableKey != nil ||
              runtimeOverrideEnvironment != nil else {
            return nil
        }
        return "Debug Menu"
    }
    #endif
}
