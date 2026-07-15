import Foundation

/// Read access to feature-flag state.
///
/// The dependency-injection seam so views and services depend on the capability,
/// not the concrete `FeatureFlagService`. `@MainActor` because the concrete
/// implementation is `@Observable` and read during SwiftUI view evaluation.
@MainActor
protocol FeatureFlagProviding {

    /// Whether `flag` is currently enabled, after applying the full resolution chain.
    func isEnabled(_ flag: FeatureFlag) -> Bool
}
