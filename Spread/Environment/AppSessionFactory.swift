/// Shim that resolves the session configuration for the current build
/// and delegates to `SessionFactory`.
enum AppSessionFactory {
    #if DEBUG
    private static func configuration() -> SessionConfiguration {
        .debug()
    }
    #else
    private static func configuration() -> SessionConfiguration {
        SessionConfiguration()
    }
    #endif

    @MainActor
    static func makeLive() async throws -> AppSession {
        try await SessionFactory.makeLive(configuration: configuration())
    }

    @MainActor
    static func make(container: DependencyContainer) async throws -> AppSession {
        try await SessionFactory.make(container: container, configuration: configuration())
    }
}
