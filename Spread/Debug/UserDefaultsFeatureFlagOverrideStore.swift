#if DEBUG
import Foundation

/// `UserDefaults`-backed feature-flag override store for the debug menu.
///
/// Persists per-device debug overrides across launches (DEBUG builds only).
/// Keyed by `FeatureFlag.rawValue` under a single dictionary key. The launch-argument
/// override path uses the ephemeral `InMemoryFeatureFlagOverrideStore` instead.
@MainActor
final class UserDefaultsFeatureFlagOverrideStore: FeatureFlagOverrideStore {

    private let defaults: UserDefaults
    private let storageKey = "debug.featureFlagOverrides"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOverrides() -> [FeatureFlag: Bool] {
        guard let raw = defaults.dictionary(forKey: storageKey) as? [String: Bool] else { return [:] }
        return raw.reduce(into: [:]) { result, pair in
            if let flag = FeatureFlag(rawValue: pair.key) { result[flag] = pair.value }
        }
    }

    func persist(_ overrides: [FeatureFlag: Bool]) {
        let raw = overrides.reduce(into: [String: Bool]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        defaults.set(raw, forKey: storageKey)
    }
}
#endif
