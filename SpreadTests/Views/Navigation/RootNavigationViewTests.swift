import SwiftUI
import Testing
@testable import Spread

struct RootNavigationViewTests {
    @Test func testSpreadsTabHasCorrectProperties() {
        let tab = NavigationTab.spreads

        #expect(tab.title == "Spreads")
        #expect(tab.systemImage == "book")
    }

    @Test func testCollectionsTabHasCorrectProperties() {
        let tab = NavigationTab.collections

        #expect(tab.title == "Collections")
        #expect(tab.systemImage == "folder")
    }

    @Test func testSearchTabHasCorrectProperties() {
        let tab = NavigationTab.search

        #expect(tab.title == "Search")
        #expect(tab.systemImage == "magnifyingglass")
    }

    @Test func testSettingsTabHasCorrectProperties() {
        let tab = NavigationTab.settings

        #expect(tab.title == "Settings")
        #expect(tab.systemImage == "gear")
    }

    @Test func testNavigationTabsAreInCorrectOrder() {
        let tabs = NavigationTab.allCases

        #expect(tabs.count >= 4)
        #expect(tabs.count <= 5)
        #expect(tabs[0] == .spreads)
        #expect(tabs[1] == .search)
        #expect(tabs[2] == .collections)
        #expect(tabs[3] == .settings)
    }
}
