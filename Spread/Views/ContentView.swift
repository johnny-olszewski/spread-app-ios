import OSLog
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async session initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
///
/// Supports soft restart for environment switching: calling `restartApp()` nils
/// out the session and bumps `appSessionId` to re-trigger `.task(id:)`.
struct ContentView: View {
    @State private var session: AppSession?
    @State private var appSessionId = UUID()

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "ContentView")

    private let containerOverride: DependencyContainer?

    init(container: DependencyContainer? = nil) {
        self.containerOverride = container
    }

    var body: some View {
        Group {
            if let session {
                RootNavigationView(
                    journalManager: session.journalManager,
                    authManager: session.authManager,
                    container: session.container,
                    syncEngine: session.syncEngine,
                    onRestartRequired: restartApp,
                    makeDebugMenuView: session.makeDebugMenuView
                )
            } else {
                loadingView
            }
        }
        .task(id: appSessionId) {
            await initializeApp()
        }
        .alert(
            "Local Data Found",
            isPresented: Binding(
                get: { session?.coordinator.isShowingMigrationPrompt ?? false },
                set: { newValue in
                    if !newValue { session?.coordinator.isShowingMigrationPrompt = false }
                }
            )
        ) {
            Button("Merge into Account") {
                Task {
                    await session?.coordinator.handleMigrationDecision(.merge)
                }
            }
            Button("Discard Local Data", role: .destructive) {
                Task {
                    await session?.coordinator.handleMigrationDecision(.discard)
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

    /// Tears down the session and re-triggers app initialization.
    ///
    /// Called after an environment switch to rebuild the service graph
    /// with fresh instances bound to the new data environment.
    private func restartApp() {
        Self.logger.info("Soft restart initiated")
        session = nil
        appSessionId = UUID()
    }

    // MARK: - Initialization

    private func initializeApp() async {
        do {
            if let containerOverride {
                session = try await AppSessionFactory.make(container: containerOverride)
            } else {
                session = try await AppSessionFactory.makeLive()
            }
        } catch {
            // TODO: SPRD-45 - Add error handling UI for initialization failures
            fatalError("Failed to initialize app session: \(error)")
        }
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
