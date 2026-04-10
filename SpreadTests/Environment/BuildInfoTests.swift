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

    /// Conditions: Tests run under the QA scheme.
    /// Expected: configurationName should reflect the QA build configuration.
    @Test func testConfigurationNameMatchesQAScheme() {
        #expect(BuildInfo.configurationName == "QA")
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
