import SwiftUI
import Testing
@testable import Spread

struct RootNavigationViewTests {

    // MARK: - Navigation Layout Type Tests

    /// Conditions: Horizontal size class is regular (iPad).
    /// Expected: Navigation layout type is sidebar.
    @Test func testNavigationLayoutTypeReturnsSidebarForRegularSizeClass() {
        let layoutType = NavigationLayoutType.forSizeClass(.regular)

        #expect(layoutType == .sidebar)
    }

    /// Conditions: Horizontal size class is compact (iPhone).
    /// Expected: Navigation layout type is tabBar.
    @Test func testNavigationLayoutTypeReturnsTabBarForCompactSizeClass() {
        let layoutType = NavigationLayoutType.forSizeClass(.compact)

        #expect(layoutType == .tabBar)
    }

    /// Conditions: Horizontal size class is nil (unknown).
    /// Expected: Navigation layout type defaults to tabBar.
    @Test func testNavigationLayoutTypeDefaultsToTabBarForNilSizeClass() {
        let layoutType = NavigationLayoutType.forSizeClass(nil)

        #expect(layoutType == .tabBar)
    }

    // MARK: - Navigation Tab Tests

    /// Conditions: Access the spreads navigation tab.
    /// Expected: Tab has correct title and system image.
    @Test func testSpreadsTabHasCorrectProperties() {
        let tab = NavigationTab.spreads

        #expect(tab.title == "Spreads")
        #expect(tab.systemImage == "book")
    }

    /// Conditions: Access the collections navigation tab.
    /// Expected: Tab has correct title and system image.
    @Test func testCollectionsTabHasCorrectProperties() {
        let tab = NavigationTab.collections

        #expect(tab.title == "Collections")
        #expect(tab.systemImage == "folder")
    }

    /// Conditions: Access the settings navigation tab.
    /// Expected: Tab has correct title and system image.
    @Test func testSettingsTabHasCorrectProperties() {
        let tab = NavigationTab.settings

        #expect(tab.title == "Settings")
        #expect(tab.systemImage == "gear")
    }

    // MARK: - Navigation Tab Order Tests

    /// Conditions: Access all cases of NavigationTab.
    /// Expected: Tabs are ordered as spreads, collections, settings (plus debug in DEBUG builds).
    @Test func testNavigationTabsAreInCorrectOrder() {
        let tabs = NavigationTab.allCases

        // Minimum 3 tabs required; 4 in DEBUG builds (includes debug tab)
        #expect(tabs.count >= 3)
        #expect(tabs.count <= 4)
        #expect(tabs[0] == .spreads)
        #expect(tabs[1] == .collections)
        #expect(tabs[2] == .settings)
    }

    // MARK: - Sidebar Item Tests

    /// Conditions: Access the spreads sidebar item.
    /// Expected: Item has correct title and system image.
    @Test func testSpreadsSidebarItemHasCorrectProperties() {
        let item = SidebarItem.spreads

        #expect(item.title == "Spreads")
        #expect(item.systemImage == "book")
    }

    /// Conditions: Access the collections sidebar item.
    /// Expected: Item has correct title and system image.
    @Test func testCollectionsSidebarItemHasCorrectProperties() {
        let item = SidebarItem.collections

        #expect(item.title == "Collections")
        #expect(item.systemImage == "folder")
    }

    /// Conditions: Access the settings sidebar item.
    /// Expected: Item has correct title and system image.
    @Test func testSettingsSidebarItemHasCorrectProperties() {
        let item = SidebarItem.settings

        #expect(item.title == "Settings")
        #expect(item.systemImage == "gear")
    }

    // MARK: - Sidebar Item Order Tests

    /// Conditions: Access all cases of SidebarItem.
    /// Expected: Items are ordered as spreads, collections, settings (plus debug in DEBUG builds).
    @Test func testSidebarItemsAreInCorrectOrder() {
        let items = SidebarItem.allCases

        // Minimum 3 items required; 4 in DEBUG builds (includes debug item)
        #expect(items.count >= 3)
        #expect(items.count <= 4)
        #expect(items[0] == .spreads)
        #expect(items[1] == .collections)
        #expect(items[2] == .settings)
    }

    // MARK: - Root Navigation Composition Tests

    /// Conditions: RootNavigationView is created with a sidebar layout override.
    /// Expected: The resolved layout type is sidebar.
    @MainActor
    @Test func testRootNavigationViewUsesSidebarLayoutOverride() throws {
        let container = try DependencyContainer.makeForPreview()
        let view = RootNavigationView(
            journalManager: .previewInstance,
            container: container,
            layoutOverride: .sidebar
        )

        #expect(view.layoutType == .sidebar)
    }

    /// Conditions: RootNavigationView is created with a tab bar layout override.
    /// Expected: The resolved layout type is tabBar.
    @MainActor
    @Test func testRootNavigationViewUsesTabBarLayoutOverride() throws {
        let container = try DependencyContainer.makeForPreview()
        let view = RootNavigationView(
            journalManager: .previewInstance,
            container: container,
            layoutOverride: .tabBar
        )

        #expect(view.layoutType == .tabBar)
    }
}
