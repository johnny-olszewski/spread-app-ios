import OSLog
import SwiftUI

@main
struct SpreadApp: App {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "App")

    init() {
        SpreadApp.logSupabaseConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func logSupabaseConfiguration() {
        let dataEnv = DataEnvironment.current
        let host = SupabaseConfiguration.url.host ?? SupabaseConfiguration.url.absoluteString
        let overrideSource = SupabaseConfiguration.explicitOverrideSourceDescription ?? "None"
        SpreadApp.logger.info("""
            DataEnvironment: \(dataEnv.rawValue, privacy: .public), \
            Supabase available: \(SupabaseConfiguration.isAvailable, privacy: .public), \
            host: \(host, privacy: .public), \
            override: \(overrideSource, privacy: .public)
            """)
    }
}
