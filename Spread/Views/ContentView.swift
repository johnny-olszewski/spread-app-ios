import SwiftUI

/// Root view for the Spread app.
///
/// Handles async JournalManager initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
struct ContentView: View {
    @State private var journalManager: JournalManager?
    @State private var authManager = AuthManager()

    let container: DependencyContainer

    var body: some View {
        Group {
            if let journalManager {
                RootNavigationView(
                    journalManager: journalManager,
                    authManager: authManager,
                    container: container
                )
            } else {
                loadingView
            }
        }
        .task {
            await initializeJournalManager()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Initialization

    private func initializeJournalManager() async {
        do {
            #if DEBUG
            let launchConfiguration = AppLaunchConfiguration.current
            let resolvedToday = launchConfiguration.today ?? .now

            var manager = try await container.makeJournalManager(today: resolvedToday)
            if let dataSet = launchConfiguration.mockDataSet {
                try await manager.loadMockDataSet(dataSet)
            }
            journalManager = manager
            #else
            journalManager = try await container.makeJournalManager()
            #endif
        } catch {
            // TODO: SPRD-45 - Add error handling UI for initialization failures
            fatalError("Failed to initialize JournalManager: \(error)")
        }
    }
}

#Preview {
    ContentView(container: try! .makeForPreview())
}
