import Foundation
import SwiftUI
import UIKit
import Testing
@testable import Spread

@Suite("Spread Theme Tests")
struct SpreadThemeTests {

    // `UIFont(name:size:)` returning non-nil is the standard way to confirm a bundled font's
    // PostScript name actually registered via Info.plist's UIAppFonts (rather than silently
    // falling back to the system font, which `Font.custom` does at runtime if the name is wrong).

    /// Conditions: `FuzzyBubbles-Bold` is registered in `Info.plist`'s `UIAppFonts`.
    /// Expected: `UIFont(name:size:)` resolves it — confirms the bundled font file loaded.
    @Test func testFuzzyBubblesBoldIsRegistered() {
        #expect(UIFont(name: SpreadTheme.FontFamily.largeTitleBold, size: 12) != nil)
    }

    /// Conditions: `FuzzyBubbles-Regular` is registered in `Info.plist`'s `UIAppFonts`.
    /// Expected: `UIFont(name:size:)` resolves it.
    @Test func testFuzzyBubblesRegularIsRegistered() {
        #expect(UIFont(name: SpreadTheme.FontFamily.largeTitleRegular, size: 12) != nil)
    }

    /// Conditions: `largeTitle(size:weight:)` called with default arguments.
    /// Expected: Matches the prior fixed `largeTitle` default — 28pt, Bold weight (now Fuzzy
    /// Bubbles Bold instead of Avenir Next Bold).
    @Test func testLargeTitleDefaultsTo28PointBold() {
        #expect(SpreadTheme.Typography.largeTitle() == .custom("FuzzyBubbles-Bold", size: 28))
    }

    /// Conditions: `largeTitle(size:weight:)` called with a custom size and `.regular` weight.
    /// Expected: Resolves to the Regular PostScript name at the requested size — confirms the
    /// function is genuinely configurable, not just the default.
    @Test func testLargeTitleConfigurableSizeAndWeight() {
        #expect(SpreadTheme.Typography.largeTitle(size: 40, weight: .regular) == .custom("FuzzyBubbles-Regular", size: 40))
    }

    /// Conditions: `largeTitle(size:weight:)` called with a weight that isn't `.bold`.
    /// Expected: Falls back to the Regular PostScript name — only two static weights are
    /// bundled, so anything other than `.bold` resolves to Regular.
    @Test func testLargeTitleNonBoldWeightFallsBackToRegular() {
        #expect(SpreadTheme.Typography.largeTitle(size: 28, weight: .medium) == .custom("FuzzyBubbles-Regular", size: 28))
    }
}
