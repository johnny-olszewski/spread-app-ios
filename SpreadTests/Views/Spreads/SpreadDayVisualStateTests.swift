import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for shared day visual style properties on `SpreadCardStyle`.
@Suite("Spread Day Visual State Tests")
struct SpreadDayVisualStateTests {

    // MARK: - MultidayDayCardVisualState shared properties

    /// Condition: a created today state.
    /// Expected: fill is a tinted accent color (non-clear), border is solid (no dash), border color is todayEmphasisBorder.
    @Test("today created state has tinted fill and solid border")
    func testTodayCreatedStateStyle() {
        let state = SpreadCardStyle.todayCreated
        #expect(state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.5)
    }

    /// Condition: an uncreated today state.
    /// Expected: the border remains dashed even though the day still uses today emphasis.
    @Test("today uncreated state keeps dashed border")
    func testTodayUncreatedStateStyle() {
        let state = SpreadCardStyle.todayUncreated
        #expect(!state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.5)
    }

    /// Condition: .created state.
    /// Expected: border is solid (no dash), thinner line than today.
    @Test("created state has solid border")
    func testCreatedStateStyle() {
        let state = SpreadCardStyle.created
        #expect(state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.0)
    }

    /// Condition: .uncreated state.
    /// Expected: border is dashed (non-empty dash array), same line width as created.
    @Test("uncreated state has dashed border")
    func testUncreatedStateStyle() {
        let state = SpreadCardStyle.uncreated
        #expect(!state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.0)
    }

    /// Condition: today-emphasis and created/uncreated states have distinct border colors.
    /// Expected: today-created uses the today-emphasis tint while created/uncreated retain their neutral tones.
    @Test("each state produces a distinct border color")
    func testDistinctBorderColors() {
        let today = SpreadCardStyle.todayCreated.borderColor
        let created = SpreadCardStyle.created.borderColor
        let uncreated = SpreadCardStyle.uncreated.borderColor

        #expect(today != created)
        #expect(today != uncreated)
        #expect(created != uncreated)
    }

    /// Condition: today-emphasis and created/uncreated have distinct fills.
    /// Expected: both today variants share the same fill, which differs from created/uncreated fills.
    @Test("today states have distinct fill from other states")
    func testTodayFillDistinct() {
        let todayCreatedFill = SpreadCardStyle.todayCreated.fill
        let todayUncreatedFill = SpreadCardStyle.todayUncreated.fill
        let createdFill = SpreadCardStyle.created.fill
        let uncreatedFill = SpreadCardStyle.uncreated.fill

        #expect(todayCreatedFill == todayUncreatedFill)
        #expect(todayCreatedFill != createdFill)
        #expect(todayCreatedFill != uncreatedFill)
    }

}
