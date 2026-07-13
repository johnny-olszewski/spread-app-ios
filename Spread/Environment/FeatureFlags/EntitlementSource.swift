import Foundation

/// Per-user entitlement decisions for feature flags (permissions, premium).
///
/// The middle resolution layer between debug overrides and compile-time defaults.
/// Returning `nil` defers to the build default. The MVP ships only the no-op
/// `NoEntitlements`; a future implementation backs this with per-user data.
protocol EntitlementSource: Sendable {

    /// The entitlement decision for `flag`, or `nil` to defer to the build default.
    func entitlement(for flag: FeatureFlag) -> Bool?
}

/// Entitlement source that never grants or denies — every flag defers to its build default.
///
/// The MVP entitlement layer: the seam exists so premium/permission gating can be
/// added later without reworking resolution, but no entitlements are enforced yet.
struct NoEntitlements: EntitlementSource {

    func entitlement(for flag: FeatureFlag) -> Bool? { nil }
}
