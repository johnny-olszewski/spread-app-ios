import Foundation

/// Configuration for connecting to Supabase backend services.
///
/// Values are read from Info.plist at runtime, which are populated from
/// xcconfig files at build time:
/// - Debug builds use `Configuration/Debug.xcconfig` (dev environment)
/// - QA builds use `Configuration/QA.xcconfig` (dev environment)
/// - Release builds use `Configuration/Release.xcconfig` (prod environment)
///
/// The active configuration is determined by `DataEnvironment.current`:
/// - `localhost`: Supabase is not available (local-only mode).
/// - `development`: Uses dev Supabase URL/key.
/// - `production`: Uses prod Supabase URL/key.
///
/// Explicit URL/key overrides via launch arguments or environment variables
/// take highest priority in all builds.
enum SupabaseConfiguration {

    // MARK: - Known Environments

    private enum KnownEnvironment {
        static let devURL = URL(string: "https://apblzzondjcughtgqowd.supabase.co")!
        static let devKey = "sb_publishable_G74Nb3IoMfnsmrZfp6dcaA_0_UD6QLT"

        static let prodURL = URL(string: "https://nzsswqmxodkvgsnabnaj.supabase.co")!
        static let prodKey = "sb_publishable_NSgP9CI8D3Ab3d4QmQ9Lwg_RV2tArlj"
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

    // MARK: - Active Configuration

    /// Whether Supabase is available for the current data environment.
    ///
    /// Returns `false` for localhost (local-only mode).
    static var isAvailable: Bool {
        !DataEnvironment.current.isLocalOnly
    }

    /// The active Supabase URL based on the current data environment.
    ///
    /// Resolution order:
    /// 1. Explicit override via launch args (`-SupabaseURL`) or env vars (`SUPABASE_URL`)
    /// 2. URL for the current `DataEnvironment`
    static var url: URL {
        if let override = explicitOverride {
            return override.url
        }
        return url(for: DataEnvironment.current)
    }

    /// The active Supabase publishable key based on the current data environment.
    ///
    /// Resolution order:
    /// 1. Explicit override via launch args (`-SupabaseKey`) or env vars (`SUPABASE_PUBLISHABLE_KEY`)
    /// 2. Key for the current `DataEnvironment`
    static var publishableKey: String {
        if let override = explicitOverride {
            return override.key
        }
        return publishableKey(for: DataEnvironment.current)
    }

    /// Returns the Supabase URL for a specific data environment.
    static func url(for dataEnvironment: DataEnvironment) -> URL {
        switch dataEnvironment {
        case .localhost:
            return buildURL
        case .development:
            return KnownEnvironment.devURL
        case .production:
            return KnownEnvironment.prodURL
        }
    }

    /// Returns the Supabase publishable key for a specific data environment.
    static func publishableKey(for dataEnvironment: DataEnvironment) -> String {
        switch dataEnvironment {
        case .localhost:
            return buildPublishableKey
        case .development:
            return KnownEnvironment.devKey
        case .production:
            return KnownEnvironment.prodKey
        }
    }

    // MARK: - Explicit Overrides (Launch Args / Env Vars)

    private enum OverrideSource: String {
        case launchArguments = "Launch Arguments"
        case environmentVariables = "Environment Variables"
    }

    /// Returns an explicit URL/key override when both values are supplied
    /// via launch arguments or environment variables.
    private static var explicitOverride: (url: URL, key: String, source: OverrideSource)? {
        // 1. Launch arguments
        if let urlString = launchArgumentValue(named: "-SupabaseURL"),
           let key = launchArgumentValue(named: "-SupabaseKey"),
           let url = URL(string: urlString),
           !key.isEmpty {
            return (url, key, .launchArguments)
        }

        // 2. Environment variables
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
        explicitOverride?.source.rawValue
    }

    private static func launchArgumentValue(named name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name),
              index + 1 < arguments.count else {
            return nil
        }
        return arguments[index + 1]
    }
}
