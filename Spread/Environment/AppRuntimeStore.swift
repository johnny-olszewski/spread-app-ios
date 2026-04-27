import Observation

@Observable
@MainActor
final class AppRuntimeStore {
    private let dependenciesOverride: AppDependencies?
    private let makeLiveRuntime: () async throws -> AppRuntime
    private let makeRuntime: (AppDependencies) async throws -> AppRuntime

    private(set) var runtime: AppRuntime?
    private(set) var initializationError: Error?
    private var isInitializing = false

    init(
        dependencies: AppDependencies? = nil,
        makeLiveRuntime: @escaping () async throws -> AppRuntime = {
            try await AppRuntimeBootstrapFactory.makeLive()
        },
        makeRuntime: @escaping (AppDependencies) async throws -> AppRuntime = { dependencies in
            try await AppRuntimeBootstrapFactory.make(dependencies: dependencies)
        }
    ) {
        dependenciesOverride = dependencies
        self.makeLiveRuntime = makeLiveRuntime
        self.makeRuntime = makeRuntime
    }

    func initializeIfNeeded() async {
        guard runtime == nil, !isInitializing else { return }

        isInitializing = true
        defer { isInitializing = false }

        do {
            if let dependenciesOverride {
                runtime = try await makeRuntime(dependenciesOverride)
            } else {
                runtime = try await makeLiveRuntime()
            }
            initializationError = nil
        } catch {
            initializationError = error
        }
    }
}
