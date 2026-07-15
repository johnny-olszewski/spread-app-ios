import Foundation

/// A gated feature in the app.
///
/// Each flag carries a compile-time default; runtime resolution layers a debug
/// override and a per-user entitlement on top (see `FeatureFlagService`).
enum FeatureFlag: String, CaseIterable, Sendable {

    /// The Collections tab. Out of MVP scope — off by default, code retained.
    case collections

    /// Event-related UI and data paths. Deferred to v2 (migrated from the
    /// former `FeatureFlags.eventsEnabled` build constant).
    case events

    /// The compile-time value used when no debug override or entitlement applies.
    var buildDefault: Bool {
        switch self {
        case .collections: false
        case .events: false
        }
    }

    /// Human-readable name for debug UI.
    var displayName: String {
        switch self {
        case .collections: "Collections"
        case .events: "Events"
        }
    }
}
