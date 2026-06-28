import Foundation
import PhosphorSwift
import Testing
@testable import Spread

@Suite("Spread Theme Icon Tests")
struct SpreadThemeIconTests {

    /// Conditions: a representative sample of `SpreadTheme.Icon` cases covering every weight
    /// branch (`.regular` and `.fill`).
    /// Expected: each resolves to the expected Phosphor `Ph` case and `Ph.IconWeight`.
    @Test func testIconResolvesToExpectedPhosphorCaseAndWeight() {
        #expect(SpreadTheme.Icon.plus.phosphorIcon == .plus)
        #expect(SpreadTheme.Icon.plus.weight == .regular)

        #expect(SpreadTheme.Icon.star.phosphorIcon == .star)
        #expect(SpreadTheme.Icon.star.weight == .regular)
        #expect(SpreadTheme.Icon.starFilled.phosphorIcon == .star)
        #expect(SpreadTheme.Icon.starFilled.weight == .fill)

        #expect(SpreadTheme.Icon.circle.phosphorIcon == .circle)
        #expect(SpreadTheme.Icon.circle.weight == .regular)
        #expect(SpreadTheme.Icon.circleFilled.phosphorIcon == .circle)
        #expect(SpreadTheme.Icon.circleFilled.weight == .fill)

        #expect(SpreadTheme.Icon.arrowRightCircle.phosphorIcon == .arrowCircleRight)
        #expect(SpreadTheme.Icon.arrowRightCircle.weight == .regular)
        #expect(SpreadTheme.Icon.arrowRightCircleFilled.phosphorIcon == .arrowCircleRight)
        #expect(SpreadTheme.Icon.arrowRightCircleFilled.weight == .fill)

        #expect(SpreadTheme.Icon.calendarDots.phosphorIcon == .calendarDots)
        #expect(SpreadTheme.Icon.rows.phosphorIcon == .rows)
        #expect(SpreadTheme.Icon.bug.phosphorIcon == .bug)
        #expect(SpreadTheme.Icon.openExternal.phosphorIcon == .arrowSquareOut)
        #expect(SpreadTheme.Icon.editCompose.phosphorIcon == .notePencil)
        #expect(SpreadTheme.Icon.arrowUTurnLeft.phosphorIcon == .arrowUUpLeft)
        #expect(SpreadTheme.Icon.arrowsUpDown.phosphorIcon == .arrowsDownUp)
        #expect(SpreadTheme.Icon.noteText.phosphorIcon == .fileText)
    }

    /// Conditions: every `SpreadTheme.Icon` case.
    /// Expected: `.image` resolves without crashing for each — a basic sanity check that the
    /// `(phosphorIcon, weight)` pairing is always a valid Phosphor lookup.
    @Test func testEveryIconCaseResolvesToAnImage() {
        for icon in SpreadTheme.Icon.allCases {
            _ = icon.image
        }
        #expect(SpreadTheme.Icon.allCases.count > 0)
    }

    /// Conditions: every case whose name ends in "Filled".
    /// Expected: resolves to `.fill` weight — confirms the naming convention and the `weight`
    /// switch's case list stay in sync as cases are added.
    @Test func testFilledSuffixCasesAlwaysResolveToFillWeight() {
        let filledCases = SpreadTheme.Icon.allCases.filter { "\($0)".hasSuffix("Filled") }
        #expect(!filledCases.isEmpty)
        for icon in filledCases {
            #expect(icon.weight == .fill, "\(icon) should resolve to .fill weight")
        }
    }
}
