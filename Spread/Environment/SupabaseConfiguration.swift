import Foundation

/// Configuration for connecting to Supabase backend services.
///
/// Values are read from Info.plist at runtime, which are populated from
/// xcconfig files at build time:
/// - Debug builds use `Configuration/Debug.xcconfig` (dev environment)
/// - Release builds use `Configuration/Release.xcconfig` (prod environment)
///
/// Debug builds can switch environments at runtime via the Debug menu (SPRD-86).
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
    /// In Release builds, this always returns the build-time configuration.
    static var url: URL {
        #if DEBUG
        return runtimeOverrideURL ?? buildURL
        #else
        return buildURL
        #endif
    }

    /// The active Supabase publishable key to use.
    ///
    /// In Debug builds, this can be overridden via the Debug menu (SPRD-86).
    /// In Release builds, this always returns the build-time configuration.
    static var publishableKey: String {
        #if DEBUG
        return runtimeOverridePublishableKey ?? buildPublishableKey
        #else
        return buildPublishableKey
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
}
