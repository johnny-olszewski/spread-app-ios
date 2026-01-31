import OSLog
import SwiftUI

@main
struct SpreadApp: App {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "App")
    private let container: DependencyContainer

    init() {
        logSupabaseConfiguration()
        do {
            container = try DependencyContainer.make(for: .current)
        } catch {
            fatalError("Failed to create DependencyContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }

    private func logSupabaseConfiguration() {
        let host = SupabaseConfiguration.url.host ?? SupabaseConfiguration.url.absoluteString
        var overrideSource = SupabaseConfiguration.explicitOverrideSourceDescription ?? "None"
        #if DEBUG
        if let runtimeOverride = SupabaseConfiguration.runtimeOverrideDescription {
            overrideSource = runtimeOverride
        }
        #endif
        SpreadApp.logger.info("Supabase host: \(host, privacy: .public) (override: \(overrideSource, privacy: .public))")
    }
}
