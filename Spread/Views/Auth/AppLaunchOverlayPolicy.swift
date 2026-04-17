import Foundation

/// Overlay states shown during app launch and authentication transitions.
enum AppLaunchOverlay: Equatable {
    case none
    case authGate
    case onboarding
}

/// Resolves which launch overlay should be shown for the current app state.
struct AppLaunchOverlayPolicy {
    static func overlay(
        environment: DataEnvironment,
        isSignedIn: Bool,
        hasCompletedOnboarding: Bool
    ) -> AppLaunchOverlay {
        guard environment.requiresAuth else {
            return .none
        }

        if !isSignedIn {
            return .authGate
        }

        if !hasCompletedOnboarding {
            return .onboarding
        }

        return .none
    }
}
