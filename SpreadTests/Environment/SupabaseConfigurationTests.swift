import Testing
@testable import Spread

struct SupabaseConfigurationTests {

    // MARK: - Effective Environment Resolution

    /// Conditions: Release build, current environment is development, no explicit overrides.
    /// Expected: Falls back to the build default.
    @Test func testReleaseWithoutOverridesFallsBackToBuildDefault() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .development,
            isRelease: true,
            explicitOverridePresent: false,
            buildDefault: .production
        )
        #expect(result == .production)
    }

    /// Conditions: Release build, current environment is development, explicit overrides present.
    /// Expected: Uses the current environment.
    @Test func testReleaseWithOverridesUsesCurrentEnvironment() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .development,
            isRelease: true,
            explicitOverridePresent: true,
            buildDefault: .production
        )
        #expect(result == .development)
    }

    /// Conditions: Debug build, current environment is localhost, no explicit overrides.
    /// Expected: Uses the current environment.
    @Test func testDebugBuildKeepsCurrentEnvironment() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .localhost,
            isRelease: false,
            explicitOverridePresent: false,
            buildDefault: .production
        )
        #expect(result == .localhost)
    }

    /// Conditions: Release build, current environment is production, no explicit overrides.
    /// Expected: Uses production.
    @Test func testReleaseUsesProductionWhenCurrentIsProduction() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .production,
            isRelease: true,
            explicitOverridePresent: false,
            buildDefault: .production
        )
        #expect(result == .production)
    }

    /// Conditions: Release build, current environment is localhost, no explicit overrides.
    /// Expected: Falls back to build default.
    @Test func testReleaseLocalhostWithoutOverridesFallsBackToBuildDefault() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .localhost,
            isRelease: true,
            explicitOverridePresent: false,
            buildDefault: .production
        )
        #expect(result == .production)
    }

    /// Conditions: Release build, current environment is localhost, explicit overrides present.
    /// Expected: Uses the current environment.
    @Test func testReleaseLocalhostWithOverridesUsesCurrentEnvironment() {
        let result = SupabaseConfiguration.resolvedDataEnvironment(
            current: .localhost,
            isRelease: true,
            explicitOverridePresent: true,
            buildDefault: .production
        )
        #expect(result == .localhost)
    }
}
