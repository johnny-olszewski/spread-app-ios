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

    /// Conditions: Tests run under the Debug build configuration with a non-QA bundle identifier.
    /// Expected: configurationName should be "Debug" (not "QA" since the test host bundle ID
    /// does not end in ".qa").
    @Test func testConfigurationNameIsDebugInDebugBuild() {
        #expect(BuildInfo.configurationName == "Debug")
    }

    // MARK: - Consistency

    /// Conditions: Tests run under any single build configuration.
    /// Expected: allowsDebugUI and isRelease should be mutually exclusive — exactly one is true.
    @Test func testAllowsDebugUIAndIsReleaseAreMutuallyExclusive() {
        #expect(BuildInfo.allowsDebugUI != BuildInfo.isRelease)
    }
}
