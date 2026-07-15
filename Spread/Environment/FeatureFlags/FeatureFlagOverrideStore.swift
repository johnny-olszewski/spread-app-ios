import Foundation

/// Persistence seam for debug-only feature-flag overrides.
///
/// The top resolution layer. Only wired in DEBUG builds (launch arguments and the
/// debug menu); release builds inject no store, so overrides never apply. Kept as a
/// protocol so the in-memory (launch-arg / test) and `UserDefaults`-backed (debug menu)
/// stores are interchangeable.
@MainActor
protocol FeatureFlagOverrideStore {

    /// The currently persisted overrides. Absent keys defer to lower resolution layers.
    func loadOverrides() -> [FeatureFlag: Bool]

    /// Persists the full override set, replacing any previously stored overrides.
    func persist(_ overrides: [FeatureFlag: Bool])
}

/// In-memory override store with no persistence.
///
/// Backs both unit tests and the DEBUG per-launch argument overrides (which are
/// intentionally ephemeral). The `UserDefaults`-backed store used by the debug-menu
/// toggles is a separate type.
@MainActor
final class InMemoryFeatureFlagOverrideStore: FeatureFlagOverrideStore {

    private var overrides: [FeatureFlag: Bool]

    init(overrides: [FeatureFlag: Bool] = [:]) {
        self.overrides = overrides
    }

    func loadOverrides() -> [FeatureFlag: Bool] { overrides }

    func persist(_ overrides: [FeatureFlag: Bool]) { self.overrides = overrides }
}
