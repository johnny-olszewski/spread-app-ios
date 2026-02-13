/// Shim that resolves the runtime configuration for the current build
/// and delegates to `AppRuntimeFactory`.
enum AppRuntimeBootstrapFactory {
    #if DEBUG
    private static func configuration() -> AppRuntimeConfiguration {
        .debug()
    }
    #else
    private static func configuration() -> AppRuntimeConfiguration {
        AppRuntimeConfiguration()
    }
    #endif

    @MainActor
    static func makeLive() async throws -> AppRuntime {
        try await AppRuntimeFactory.makeLive(configuration: configuration())
    }

    @MainActor
    static func make(container: DependencyContainer) async throws -> AppRuntime {
        try await AppRuntimeFactory.make(container: container, configuration: configuration())
    }
}
