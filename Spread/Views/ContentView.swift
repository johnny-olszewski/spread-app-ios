import OSLog
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async runtime initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
///
/// Supports soft restart for environment switching: calling `restartApp()` nils
/// out the runtime and bumps `appRuntimeId` to re-trigger `.task(id:)`.
struct ContentView: View {
    @State private var runtime: AppRuntime?
    @State private var appRuntimeId = UUID()

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "ContentView")

    private let containerOverride: DependencyContainer?

    init(container: DependencyContainer? = nil) {
        self.containerOverride = container
    }

    var body: some View {
        Group {
            if let runtime {
                RootNavigationView(
                    journalManager: runtime.journalManager,
                    authManager: runtime.authManager,
                    container: runtime.container,
                    syncEngine: runtime.syncEngine,
                    onRestartRequired: restartApp,
                    makeDebugMenuView: runtime.makeDebugMenuView
                )
            } else {
                loadingView
            }
        }
        .task(id: appRuntimeId) {
            await initializeApp()
        }
        .alert(
            "Local Data Found",
            isPresented: Binding(
                get: { runtime?.coordinator.isShowingMigrationPrompt ?? false },
                set: { newValue in
                    if !newValue { runtime?.coordinator.isShowingMigrationPrompt = false }
                }
            )
        ) {
            Button("Merge into Account") {
                Task {
                    await runtime?.coordinator.handleMigrationDecision(.merge)
                }
            }
            Button("Discard Local Data", role: .destructive) {
                Task {
                    await runtime?.coordinator.handleMigrationDecision(.discard)
                }
            }
        } message: {
            Text(
                "This device has local data from a signed-out session. "
                    + "Choose whether to merge it into this account or discard it."
            )
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Soft Restart

    /// Tears down the runtime and re-triggers app initialization.
    ///
    /// Called after an environment switch to rebuild the service graph
    /// with fresh instances bound to the new data environment.
    private func restartApp() {
        Self.logger.info("Soft restart initiated")
        runtime = nil
        appRuntimeId = UUID()
    }

    // MARK: - Initialization

    private func initializeApp() async {
        do {
            if let containerOverride {
                runtime = try await AppRuntimeBootstrapFactory.make(container: containerOverride)
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
    ContentView(container: try! .makeForPreview())
}
