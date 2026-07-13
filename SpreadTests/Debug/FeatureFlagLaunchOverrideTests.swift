import Testing
@testable import Spread

/// Tests for `AppLaunchConfiguration.featureFlagOverrides(from:)` — the
/// `-FeatureFlagOverride <flag>=<on|off>` launch-argument parser (SPRD-310, AC5).
struct FeatureFlagLaunchOverrideTests {

    /// Conditions: A single `-FeatureFlagOverride collections=on` argument.
    /// Expected: `collections` maps to true; other flags are absent.
    @Test func parsesSingleEnableOverride() {
        let overrides = AppLaunchConfiguration.featureFlagOverrides(
            from: ["-FeatureFlagOverride", "collections=on"]
        )
        #expect(overrides[.collections] == true)
        #expect(overrides[.events] == nil)
    }

    /// Conditions: Multiple overrides with mixed truthy/falsy spellings.
    /// Expected: Each flag parses to the expected boolean; `off` is false.
    @Test func parsesMultipleOverridesWithMixedSpellings() {
        let overrides = AppLaunchConfiguration.featureFlagOverrides(
            from: [
                "-FeatureFlagOverride", "collections=on",
                "-FeatureFlagOverride", "events=off",
                "-SomeOtherArg", "ignored"
            ]
        )
        #expect(overrides[.collections] == true)
        #expect(overrides[.events] == false)
    }

    /// Conditions: An unknown flag name and a malformed token.
    /// Expected: Both are ignored, yielding no overrides.
    @Test func ignoresUnknownAndMalformedTokens() {
        let overrides = AppLaunchConfiguration.featureFlagOverrides(
            from: [
                "-FeatureFlagOverride", "nonexistent=on",
                "-FeatureFlagOverride", "collectionsWithoutValue"
            ]
        )
        #expect(overrides.isEmpty)
    }

    /// Conditions: No feature-flag arguments.
    /// Expected: An empty override map.
    @Test func noArgumentsYieldsNoOverrides() {
        #expect(AppLaunchConfiguration.featureFlagOverrides(from: []).isEmpty)
    }
}
