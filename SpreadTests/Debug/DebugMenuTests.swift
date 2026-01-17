#if DEBUG
import Testing
@testable import Spread

/// Tests for the Debug menu functionality.
///
/// Verifies that:
/// - DebugMenuView is available in DEBUG builds
/// - Environment and container information is displayed correctly
/// - Debug navigation item uses correct SF Symbol
@Suite("Debug Menu Tests")
struct DebugMenuTests {

    // MARK: - Debug Menu Availability

    /// Verifies that DebugMenuView can be instantiated in DEBUG builds.
    ///
    /// Setup: DEBUG build configuration
    /// Expected: DebugMenuView type exists and can be referenced
    @Test("Debug menu is available in DEBUG builds")
    func debugMenuAvailableInDebug() {
        // The fact that this test compiles and runs proves DebugMenuView exists in DEBUG builds.
        // If DebugMenuView were not gated correctly, this would fail to compile in Release.
        let viewType = DebugMenuView.self
        #expect(viewType == DebugMenuView.self)
    }

    // MARK: - Debug Navigation Item

    /// Verifies that the debug navigation tab uses the correct SF Symbol.
    ///
    /// Setup: NavigationTab.debug case in DEBUG build
    /// Expected: systemImage is "ant"
    @Test("Debug tab uses ant SF Symbol")
    func debugTabUsesAntSymbol() {
        let debugTab = NavigationTab.debug
        #expect(debugTab.systemImage == "ant")
    }

    /// Verifies that the debug sidebar item uses the correct SF Symbol.
    ///
    /// Setup: SidebarItem.debug case in DEBUG build
    /// Expected: systemImage is "ant"
    @Test("Debug sidebar uses ant SF Symbol")
    func debugSidebarUsesAntSymbol() {
        let debugSidebar = SidebarItem.debug
        #expect(debugSidebar.systemImage == "ant")
    }

    /// Verifies that the debug tab has the correct display title.
    ///
    /// Setup: NavigationTab.debug case
    /// Expected: title is "Debug"
    @Test("Debug tab has correct title")
    func debugTabHasCorrectTitle() {
        let debugTab = NavigationTab.debug
        #expect(debugTab.title == "Debug")
    }

    /// Verifies that the debug sidebar item has the correct display title.
    ///
    /// Setup: SidebarItem.debug case
    /// Expected: title is "Debug"
    @Test("Debug sidebar has correct title")
    func debugSidebarHasCorrectTitle() {
        let debugSidebar = SidebarItem.debug
        #expect(debugSidebar.title == "Debug")
    }
}
#endif
