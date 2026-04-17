/// Build-time feature flags for gating unreleased functionality.
///
/// Toggle these flags to enable/disable features that are scaffolded
/// but not yet ready for release. When a feature ships, remove its
/// flag and all gating code.
enum FeatureFlags {

    /// Whether event-related UI and data paths are enabled.
    ///
    /// Events are deferred to v2 (SPRD-69). The data model, repositories,
    /// and entry row scaffolding remain compiled but gated behind this flag.
    /// Set to `true` when event integrations are ready for release.
    static let eventsEnabled = false
}
