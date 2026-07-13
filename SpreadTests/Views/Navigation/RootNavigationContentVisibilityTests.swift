import Testing
@testable import Spread

/// Tests for `RootNavigationView.Content.visibleCases(featureFlags:)` — the
/// flag-gated top-level tab list (SPRD-310).
@MainActor
struct RootNavigationContentVisibilityTests {

    /// Conditions: `collections` flag at its build default (off).
    /// Expected: The Collections tab is absent from the visible tab list.
    @Test func collectionsHiddenWhenFlagOff() {
        let flags = FeatureFlagService()
        let visible = RootNavigationView.Content.visibleCases(featureFlags: flags)
        #expect(!visible.contains(.collections))
        #expect(visible.contains(.spreads))
        #expect(visible.contains(.entries))
        #expect(visible.contains(.settings))
    }

    /// Conditions: `collections` enabled via a debug override.
    /// Expected: The Collections tab appears in the visible tab list.
    @Test func collectionsShownWhenFlagOn() {
        let flags = FeatureFlagService(
            overrideStore: InMemoryFeatureFlagOverrideStore(overrides: [.collections: true])
        )
        let visible = RootNavigationView.Content.visibleCases(featureFlags: flags)
        #expect(visible.contains(.collections))
    }

    /// Conditions: Toggling the override off then on at runtime.
    /// Expected: The visible list reflects each change (drives the live tab update).
    @Test func visibleCasesReflectsRuntimeToggle() {
        let flags = FeatureFlagService(overrideStore: InMemoryFeatureFlagOverrideStore())
        #expect(!RootNavigationView.Content.visibleCases(featureFlags: flags).contains(.collections))

        flags.setOverride(true, for: .collections)
        #expect(RootNavigationView.Content.visibleCases(featureFlags: flags).contains(.collections))

        flags.setOverride(nil, for: .collections)
        #expect(!RootNavigationView.Content.visibleCases(featureFlags: flags).contains(.collections))
    }
}
