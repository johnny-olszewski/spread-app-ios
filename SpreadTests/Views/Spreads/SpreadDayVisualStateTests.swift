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

    // MARK: - Visual state mapping helpers

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Visual state mapping

    /// Condition: today's date, no explicit day target.
    /// Expected: visual state is .todayUncreated.
    @Test("today date with no explicit day target maps to .todayUncreated")
    func testTodayMapsToTodayUncreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: true,
            hasExplicitDayTarget: false
        )
        #expect(state == .todayUncreated)
    }

    /// Condition: today's date with an explicit day target.
    /// Expected: visual state is .todayCreated.
    @Test("today date with explicit day target maps to .todayCreated")
    func testTodayWithExplicitDayTargetMapsToTodayCreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: true,
            hasExplicitDayTarget: true
        )
        #expect(state == .todayCreated)
    }

    /// Condition: non-today date with an explicit day target.
    /// Expected: visual state is .created.
    @Test("date with explicit day target maps to .created")
    func testWithExplicitDayTargetMapsToCreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            hasExplicitDayTarget: true
        )
        #expect(state == .created)
    }

    /// Condition: non-today date with no explicit day target.
    /// Expected: visual state is .uncreated (multiday coverage alone does not create a day spread).
    @Test("date without explicit day target maps to .uncreated")
    func testMultidayOnlyTargetMapsToUncreated() {
        let state = SpreadHeaderNavigatorCalendarGenerator.visualState(
            isToday: false,
            hasExplicitDayTarget: false
        )
        #expect(state == .uncreated)
    }

    // MARK: - hasExplicitDayTarget helper

    /// Condition: a target list contains only multiday selections.
    /// Expected: the helper reports no explicit day target.
    @Test("Target helper ignores multiday-only selections")
    func testHasExplicitDayTargetIgnoresMultidayOnlySelections() {
        let date = Self.makeDate(year: 2026, month: 4, day: 13)
        let spread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let multidayOnlyTargets = [
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "multiday-only",
                selection: spread,
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
        let date = Self.makeDate(year: 2026, month: 4, day: 13)
        let spread = DataModel.Spread(period: .day, date: date, calendar: Self.calendar)
        let mixedTargets = [
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "day",
                selection: spread,
                title: "View Day",
                isMultiday: false
            ),
            SpreadHeaderNavigatorModel.SelectionTarget(
                id: "multiday",
                selection: spread,
                title: "Multiday",
                isMultiday: true
            )
        ]

        #expect(SpreadHeaderNavigatorCalendarGenerator.hasExplicitDayTarget(mixedTargets))
    }
}
