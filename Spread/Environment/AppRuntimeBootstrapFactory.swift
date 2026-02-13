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
    static func make(dependencies: AppDependencies) async throws -> AppRuntime {
        try await AppRuntimeFactory.make(dependencies: dependencies, configuration: configuration())
    }
}
