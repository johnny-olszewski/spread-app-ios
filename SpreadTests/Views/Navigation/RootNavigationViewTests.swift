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

    @Test func testSettingsTabHasCorrectProperties() {
        let tab = NavigationTab.settings

        #expect(tab.title == "Settings")
        #expect(tab.systemImage == "gear")
    }

    @Test func testNavigationTabsAreInCorrectOrder() {
        let tabs = NavigationTab.allCases

        #expect(tabs.count >= 3)
        #expect(tabs.count <= 4)
        #expect(tabs[0] == .spreads)
        #expect(tabs[1] == .collections)
        #expect(tabs[2] == .settings)
    }
}
