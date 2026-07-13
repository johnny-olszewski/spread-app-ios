import Foundation
import Observation

/// Resolves feature-flag state through a three-layer chain:
/// `debugOverride ?? entitlement ?? buildDefault`.
///
/// `@Observable` so SwiftUI surfaces that read `isEnabled` during body evaluation
/// (e.g. the root tab list) recompute when a debug override is toggled at runtime.
/// In release builds no override store is injected, so the debug layer is inert and
/// resolution collapses to `entitlement ?? buildDefault`.
@Observable
@MainActor
final class FeatureFlagService: FeatureFlagProviding {

    // MARK: - Properties

    private let entitlements: any EntitlementSource
    private let overrideStore: (any FeatureFlagOverrideStore)?
    private var overrides: [FeatureFlag: Bool]

    // MARK: - Init

    /// - Parameters:
    ///   - entitlements: Per-user entitlement layer. Defaults to `NoEntitlements` (MVP).
    ///   - overrideStore: Debug-override persistence. `nil` in release — overrides never apply.
    init(
        entitlements: any EntitlementSource = NoEntitlements(),
        overrideStore: (any FeatureFlagOverrideStore)? = nil
    ) {
        self.entitlements = entitlements
        self.overrideStore = overrideStore
        self.overrides = overrideStore?.loadOverrides() ?? [:]
    }

    // MARK: - FeatureFlagProviding

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        if let override = overrides[flag] { return override }
        if let entitled = entitlements.entitlement(for: flag) { return entitled }
        return flag.buildDefault
    }

    // MARK: - Debug Overrides

    /// The current debug override for `flag`, or `nil` if none is set.
    func override(for flag: FeatureFlag) -> Bool? { overrides[flag] }

    /// Sets (or clears, when `value` is `nil`) a debug override and persists it.
    ///
    /// Only exercised by DEBUG surfaces; a release build never injects a store or
    /// calls this, so overrides stay empty.
    func setOverride(_ value: Bool?, for flag: FeatureFlag) {
        overrides[flag] = value
        overrideStore?.persist(overrides)
    }
}
