import OSLog
import SwiftUI

/// Root view for the Spread app.
///
/// Handles async runtime initialization and displays the appropriate
/// navigation shell once ready. Shows a loading state during initialization.
/// Auth lifecycle logic is delegated to `AuthLifecycleCoordinator`.
struct ContentView: View {
    @State private var runtime: AppRuntime?
    @State private var hasCompletedOnboarding: Bool

    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "ContentView")

    private let dependenciesOverride: AppDependencies?
    private let dataEnvironmentOverride: DataEnvironment?
    private let onboardingStore: any OnboardingStateStoring

    init(
        dependencies: AppDependencies? = nil,
        dataEnvironment: DataEnvironment? = nil,
        onboardingStore: any OnboardingStateStoring = OnboardingStateStore()
    ) {
        self.dependenciesOverride = dependencies
        self.dataEnvironmentOverride = dataEnvironment
        self.onboardingStore = onboardingStore
        _hasCompletedOnboarding = State(initialValue: onboardingStore.hasCompletedOnboarding)
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
        .sheet(isPresented: blockingAuthGateBinding) {
            if let runtime {
                AuthEntrySheet(
                    authManager: runtime.authManager,
                    isBlocking: true
                )
            }
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingSheet {
                hasCompletedOnboarding = true
                onboardingStore.markCompleted()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var currentDataEnvironment: DataEnvironment {
        dataEnvironmentOverride ?? DataEnvironment.current
    }

    private var activeOverlay: AppLaunchOverlay {
        guard let runtime else { return .none }
        return AppLaunchOverlayPolicy.overlay(
            environment: currentDataEnvironment,
            isSignedIn: runtime.authManager.state.isSignedIn,
            hasCompletedOnboarding: hasCompletedOnboarding
        )
    }

    private var blockingAuthGateBinding: Binding<Bool> {
        Binding(
            get: { activeOverlay == .authGate },
            set: { _ in }
        )
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { activeOverlay == .onboarding },
            set: { _ in }
        )
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
    ContentView(
        dependencies: try! .makeForPreview(),
        dataEnvironment: .localhost
    )
}
