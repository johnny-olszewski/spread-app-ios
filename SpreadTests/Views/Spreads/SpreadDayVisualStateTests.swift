import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for shared day visual style properties on `MultidayDayCardVisualState` and
/// the visual state mapping logic used by `SpreadHeaderNavigatorCalendarGenerator`.
@Suite("Spread Day Visual State Tests")
struct SpreadDayVisualStateTests {

    // MARK: - MultidayDayCardVisualState shared properties

    /// Condition: a created today state.
    /// Expected: fill is a tinted accent color (non-clear), border is solid (no dash), border color is todayEmphasisBorder.
    @Test("today created state has tinted fill and solid border")
    func testTodayCreatedStateStyle() {
        let state = MultidayDayCardVisualState.todayCreated
        #expect(state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.5)
    }

    /// Condition: an uncreated today state.
    /// Expected: the border remains dashed even though the day still uses today emphasis.
    @Test("today uncreated state keeps dashed border")
    func testTodayUncreatedStateStyle() {
        let state = MultidayDayCardVisualState.todayUncreated
        #expect(!state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.5)
    }

    /// Condition: .created state.
    /// Expected: border is solid (no dash), thinner line than today.
    @Test("created state has solid border")
    func testCreatedStateStyle() {
        let state = MultidayDayCardVisualState.created
        #expect(state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.0)
    }

    /// Condition: .uncreated state.
    /// Expected: border is dashed (non-empty dash array), same line width as created.
    @Test("uncreated state has dashed border")
    func testUncreatedStateStyle() {
        let state = MultidayDayCardVisualState.uncreated
        #expect(!state.borderStyle.dash.isEmpty)
        #expect(state.borderStyle.lineWidth == 1.0)
    }

    /// Condition: today-emphasis and created/uncreated states have distinct border colors.
    /// Expected: today-created uses the today-emphasis tint while created/uncreated retain their neutral tones.
    @Test("each state produces a distinct border color")
    func testDistinctBorderColors() {
        let today = MultidayDayCardVisualState.todayCreated.borderColor
        let created = MultidayDayCardVisualState.created.borderColor
        let uncreated = MultidayDayCardVisualState.uncreated.borderColor

        #expect(today != created)
        #expect(today != uncreated)
        #expect(created != uncreated)
    }

    /// Condition: today-emphasis and created/uncreated have distinct fills.
    /// Expected: both today variants share the same fill, which differs from created/uncreated fills.
    @Test("today states have distinct fill from other states")
    func testTodayFillDistinct() {
        let todayCreatedFill = MultidayDayCardVisualState.todayCreated.fill
        let todayUncreatedFill = MultidayDayCardVisualState.todayUncreated.fill
        let createdFill = MultidayDayCardVisualState.created.fill
        let uncreatedFill = MultidayDayCardVisualState.uncreated.fill

        #expect(todayCreatedFill == todayUncreatedFill)
        #expect(todayCreatedFill != createdFill)
        #expect(todayCreatedFill != uncreatedFill)
    }

    // MARK: - Visual state mapping helpers

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Conventional mode mapping

    /// Condition: Conventional mode, today's date.
    /// Expected: visual state is .today regardless of targets.
    @Test("Conventional mode: today date maps to .today")
    func testConventionalTodayMapsToToday() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: true,
            mode: .conventional,
            hasExplicitDayTarget: false
        )
        #expect(state == .todayUncreated)
    }

    /// Condition: Conventional mode, non-today date with an explicit day target.
    /// Expected: visual state is .created.
    @Test("Conventional mode: date with explicit day target maps to .created")
    func testConventionalWithExplicitDayTargetMapsToCreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            mode: .conventional,
            hasExplicitDayTarget: true
        )
        #expect(state == .created)
    }

    /// Condition: Conventional mode, non-today date with only multiday targets.
    /// Expected: visual state is .uncreated because multiday coverage alone does not create a day spread.
    @Test("Conventional mode: multiday-only target maps to .uncreated")
    func testConventionalMultidayOnlyTargetMapsToUncreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            mode: .conventional,
            hasExplicitDayTarget: false
        )
        #expect(state == .uncreated)
    }

    // MARK: - Traditional mode mapping

    /// Condition: Traditional mode, today's date.
    /// Expected: visual state is .today.
    @Test("Traditional mode: today date maps to .today")
    func testTraditionalTodayMapsToToday() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: true,
            mode: .traditional,
            hasExplicitDayTarget: false
        )
        #expect(state == .todayCreated)
    }

    /// Condition: Traditional mode, non-today date with no targets.
    /// Expected: visual state is .created (all traditional days are navigable).
    @Test("Traditional mode: date without targets still maps to .created")
    func testTraditionalAlwaysCreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            mode: .traditional,
            hasExplicitDayTarget: false
        )
        #expect(state == .created)
    }

    /// Condition: Traditional mode, non-today date with targets.
    /// Expected: visual state is .created.
    @Test("Traditional mode: date with targets maps to .created")
    func testTraditionalWithTargetsMapsToCreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            mode: .traditional,
            hasExplicitDayTarget: true
        )
        #expect(state == .created)
    }

    /// Condition: a target list contains only multiday selections.
    /// Expected: the helper reports no explicit day target.
    @Test("Target helper ignores multiday-only selections")
    func testHasExplicitDayTargetIgnoresMultidayOnlySelections() {
        let multidayOnlyTargets = [
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "multiday-only",
                selection: .traditionalDay(Self.makeDate(year: 2026, month: 4, day: 13)),
                title: "Multiday",
                isMultiday: true
            )
        ]

        #expect(!SpreadHeaderNavigatorCalendarGenerator.hasExplicitDayTarget(multidayOnlyTargets))
    }

    /// Condition: a target list contains an explicit day selection before multiday selections.
    /// Expected: the helper reports that the date has an explicit day target.
    @Test("Target helper detects explicit day selection")
    func testHasExplicitDayTargetDetectsDaySelection() {
        let mixedTargets = [
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "day",
                selection: .traditionalDay(Self.makeDate(year: 2026, month: 4, day: 13)),
                title: "View Day",
                isMultiday: false
            ),
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "multiday",
                selection: .traditionalDay(Self.makeDate(year: 2026, month: 4, day: 13)),
                title: "Multiday",
                isMultiday: true
            )
        ]

        #expect(SpreadHeaderNavigatorCalendarGenerator.hasExplicitDayTarget(mixedTargets))
    }
}
