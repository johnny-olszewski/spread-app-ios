import OSLog
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async runtime initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
struct ContentView: View {
    @State private var runtime: AppRuntime?

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "ContentView")

    private let dependenciesOverride: AppDependencies?

    init(dependencies: AppDependencies? = nil) {
        self.dependenciesOverride = dependencies
    }

    var body: some View {
        Group {
            if let runtime {
                RootNavigationView(
                    journalManager: runtime.journalManager,
                    authManager: runtime.authManager,
                    dependencies: runtime.dependencies,
                    syncEngine: runtime.syncEngine,
                    makeDebugMenuView: runtime.makeDebugMenuView
                )
            } else {
                loadingView
            }
        }
        .task {
            await initializeApp()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Initialization

    private func initializeApp() async {
        do {
            if let dependenciesOverride {
                runtime = try await AppRuntimeBootstrapFactory.make(dependencies: dependenciesOverride)
            } else {
                runtime = try await AppRuntimeBootstrapFactory.makeLive()
            }
        } catch {
            // TODO: SPRD-45 - Add error handling UI for initialization failures
            fatalError("Failed to initialize app runtime: \(error)")
        }
    }
}

#Preview {
    ContentView(dependencies: try! .makeForPreview())
}
