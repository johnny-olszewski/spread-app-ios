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

    /// Conditions: All four bundled Mulish named-instance weights, registered via the single
    /// `Mulish-Variable.ttf` in `Info.plist`'s `UIAppFonts`.
    /// Expected: `UIFont(name:size:)` resolves each — confirms the variable font's named
    /// instances are individually addressable, not just the family as a whole.
    @Test(arguments: [
        SpreadTheme.FontFamily.headingRegular,
        SpreadTheme.FontFamily.headingMedium,
        SpreadTheme.FontFamily.headingSemiBold,
        SpreadTheme.FontFamily.headingBold
    ])
    func testMulishWeightIsRegistered(postScriptName: String) {
        #expect(UIFont(name: postScriptName, size: 12) != nil)
    }

    /// Conditions: `heading(size:weight:)` called with each of the four bundled weights.
    /// Expected: Each resolves to its matching named-instance PostScript name.
    @Test func testHeadingMapsWeightToCorrectMulishInstance() {
        #expect(SpreadTheme.Typography.heading(size: 20, weight: .regular) == .custom("MulishRoman-Regular", size: 20))
        #expect(SpreadTheme.Typography.heading(size: 20, weight: .medium) == .custom("MulishRoman-Medium", size: 20))
        #expect(SpreadTheme.Typography.heading(size: 20, weight: .semibold) == .custom("MulishRoman-SemiBold", size: 20))
        #expect(SpreadTheme.Typography.heading(size: 20, weight: .bold) == .custom("MulishRoman-Bold", size: 20))
    }

    /// Conditions: `heading(size:weight:)` called with a weight that has no bundled instance
    /// (e.g. `.black`).
    /// Expected: Falls back to the Regular instance rather than producing an unmapped/invalid font.
    @Test func testHeadingUnmappedWeightFallsBackToRegular() {
        #expect(SpreadTheme.Typography.heading(size: 20, weight: .black) == .custom("MulishRoman-Regular", size: 20))
    }

    /// Conditions: `title`/`title2`/`title3`, unchanged since SPRD-266.
    /// Expected: Each still resolves through `heading(size:weight:)` to the expected Mulish
    /// instance/size — confirms the font-family swap didn't change the existing size/weight scale.
    @Test func testTitleScaleUnchangedSizesAndWeights() {
        #expect(SpreadTheme.Typography.title == .custom("MulishRoman-SemiBold", size: 22))
        #expect(SpreadTheme.Typography.title2 == .custom("MulishRoman-SemiBold", size: 20))
        #expect(SpreadTheme.Typography.title3 == .custom("MulishRoman-Medium", size: 18))
    }
}
