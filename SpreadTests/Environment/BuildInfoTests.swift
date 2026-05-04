import Foundation
import Testing
@testable import Spread

struct BuildInfoTests {

    // MARK: - allowsDebugUI

    /// Conditions: Tests run under the Debug build configuration (DEBUG flag is set).
    /// Expected: allowsDebugUI should be true since tests compile with DEBUG.
    @Test func testAllowsDebugUIIsTrueInDebugBuild() {
        #expect(BuildInfo.allowsDebugUI == true)
    }

    // MARK: - isRelease

    /// Conditions: Tests run under the Debug build configuration (DEBUG flag is set).
    /// Expected: isRelease should be false since tests compile with DEBUG.
    @Test func testIsReleaseIsFalseInDebugBuild() {
        #expect(BuildInfo.isRelease == false)
    }

    // MARK: - configurationName

    /// Conditions: Tests run under any shared app scheme.
    /// Expected: configurationName reflects the active Debug, QA, or Release build configuration.
    @Test func testConfigurationNameMatchesActiveBuildConfiguration() {
        // configurationName is determined at runtime from the app bundle identifier.
        // DEBUG is defined in both Debug and QA configurations, so we check the bundle
        // suffix to distinguish them rather than relying on the compile-time flag alone.
        let expectedConfigurationName: String
        #if DEBUG
        let appBundleID = Bundle(for: SyncEngine.self).bundleIdentifier ?? ""
        expectedConfigurationName = appBundleID.hasSuffix(".qa") ? "QA" : "Debug"
        #else
        expectedConfigurationName = "Release"
        #endif
        #expect(BuildInfo.configurationName == expectedConfigurationName)
    }

    // MARK: - Consistency

    /// Conditions: Tests run under any single build configuration.
    /// Expected: allowsDebugUI and isRelease should be mutually exclusive — exactly one is true.
    @Test func testAllowsDebugUIAndIsReleaseAreMutuallyExclusive() {
        #expect(BuildInfo.allowsDebugUI != BuildInfo.isRelease)
    }

    // MARK: - defaultDataEnvironment

    /// Conditions: Tests run under the Debug build configuration with a non-QA bundle identifier.
    /// Expected: Debug builds default to development unless localhost is selected explicitly.
    @Test func testDefaultDataEnvironmentIsDevelopmentInDebugBuild() {
        #expect(BuildInfo.defaultDataEnvironment == .development)
    }
}
