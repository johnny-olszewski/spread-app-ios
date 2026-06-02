import SwiftUI
import Testing
@testable import Spread

struct RootNavigationViewTests {
    @Test func testSpreadsTabHasCorrectProperties() {
        let tab = RootNavigationView.Content.spreads

        #expect(tab.title == "Spreads")
        #expect(tab.systemImage == "book")
    }

    @Test func testCollectionsTabHasCorrectProperties() {
        let tab = RootNavigationView.Content.collections

        #expect(tab.title == "Collections")
        #expect(tab.systemImage == "folder")
    }

    @Test func testEntriesTabHasCorrectProperties() {
        let tab = RootNavigationView.Content.entries

        #expect(tab.title == "Entries")
        #expect(tab.systemImage == "tray.full")
    }

    @Test func testSettingsTabHasCorrectProperties() {
        let tab = RootNavigationView.Content.settings

        #expect(tab.title == "Settings")
        #expect(tab.systemImage == "gear")
    }

    @Test func testRootNavigationView.ContentsAreInCorrectOrder() {
        let tabs = RootNavigationView.Content.allCases

        #expect(tabs.count >= 4)
        #expect(tabs.count <= 5)
        #expect(tabs[0] == .spreads)
        #expect(tabs[1] == .entries)
        #expect(tabs[2] == .collections)
        #expect(tabs[3] == .settings)
    }
}
