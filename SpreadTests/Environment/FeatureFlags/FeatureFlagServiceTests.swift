import Testing
@testable import Spread

/// Tests for `FeatureFlagService`'s three-layer resolution
/// (`debugOverride ?? entitlement ?? buildDefault`) and the entitlement stub (SPRD-310).
@MainActor
struct FeatureFlagServiceTests {

    /// Entitlement source returning a fixed decision per flag, for resolution tests.
    private struct StubEntitlements: EntitlementSource {
        let decisions: [FeatureFlag: Bool]
        func entitlement(for flag: FeatureFlag) -> Bool? { decisions[flag] }
    }

    // MARK: - Build default layer

    /// Conditions: No override store, `NoEntitlements`.
    /// Expected: Every flag resolves to its compile-time `buildDefault` (all off in MVP).
    @Test func resolvesToBuildDefaultWithNoOverrideOrEntitlement() {
        let service = FeatureFlagService()
        for flag in FeatureFlag.allCases {
            #expect(service.isEnabled(flag) == flag.buildDefault)
        }
        #expect(service.isEnabled(.collections) == false)
    }

    // MARK: - Entitlement layer

    /// Conditions: No override store; entitlement grants `.collections`.
    /// Expected: Entitlement overrides the (false) build default; unlisted flags stay at build default.
    @Test func entitlementOverridesBuildDefault() {
        let service = FeatureFlagService(
            entitlements: StubEntitlements(decisions: [.collections: true])
        )
        #expect(service.isEnabled(.collections) == true)
        #expect(service.isEnabled(.events) == false)
    }

    /// Conditions: The MVP `NoEntitlements` stub.
    /// Expected: It returns nil for every flag, deferring entirely to build defaults.
    @Test func noEntitlementsReturnsNilForEveryFlag() {
        let stub = NoEntitlements()
        for flag in FeatureFlag.allCases {
            #expect(stub.entitlement(for: flag) == nil)
        }
    }

    // MARK: - Override layer (precedence)

    /// Conditions: Override store enables `.collections` while entitlement denies it.
    /// Expected: The debug override wins over both entitlement and build default.
    @Test func debugOverrideWinsOverEntitlementAndBuildDefault() {
        let service = FeatureFlagService(
            entitlements: StubEntitlements(decisions: [.collections: false]),
            overrideStore: InMemoryFeatureFlagOverrideStore(overrides: [.collections: true])
        )
        #expect(service.isEnabled(.collections) == true)
    }

    /// Conditions: A false override on a flag an entitlement would grant.
    /// Expected: The override forces it off — precedence holds in both directions.
    @Test func falseOverrideForcesFlagOff() {
        let service = FeatureFlagService(
            entitlements: StubEntitlements(decisions: [.events: true]),
            overrideStore: InMemoryFeatureFlagOverrideStore(overrides: [.events: false])
        )
        #expect(service.isEnabled(.events) == false)
    }

    /// Conditions: `setOverride` sets then clears an override at runtime.
    /// Expected: Setting flips the flag; clearing (nil) falls back to the next layer.
    @Test func setOverrideThenClearFallsBackToLowerLayers() {
        let service = FeatureFlagService(
            overrideStore: InMemoryFeatureFlagOverrideStore()
        )
        #expect(service.isEnabled(.collections) == false)

        service.setOverride(true, for: .collections)
        #expect(service.isEnabled(.collections) == true)
        #expect(service.override(for: .collections) == true)

        service.setOverride(nil, for: .collections)
        #expect(service.isEnabled(.collections) == false)
        #expect(service.override(for: .collections) == nil)
    }

    /// Conditions: A service seeded from a store, then an override persisted through it.
    /// Expected: The store receives the persisted set (persistence seam is exercised).
    @Test func setOverridePersistsThroughStore() {
        let store = InMemoryFeatureFlagOverrideStore()
        let service = FeatureFlagService(overrideStore: store)

        service.setOverride(true, for: .collections)

        #expect(store.loadOverrides()[.collections] == true)
    }
}
