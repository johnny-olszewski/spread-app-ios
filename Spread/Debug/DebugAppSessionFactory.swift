#if DEBUG
enum DebugAppSessionFactory {
    @MainActor
    static func makeLive() async throws -> AppSession {
        DebugHooksInstaller.install()
        return try await ProdAppSessionFactory.makeLive()
    }

    @MainActor
    static func make(container: DependencyContainer) async throws -> AppSession {
        DebugHooksInstaller.install()
        return try await ProdAppSessionFactory.make(container: container)
    }
}
#endif
