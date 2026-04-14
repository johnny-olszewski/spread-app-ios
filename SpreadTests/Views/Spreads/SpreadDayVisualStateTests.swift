import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for shared day visual style properties on `MultidayDayCardVisualState` and
/// the visual state mapping logic used by `SpreadHeaderNavigatorCalendarGenerator`.
@Suite("Spread Day Visual State Tests")
struct SpreadDayVisualStateTests {

    // MARK: - MultidayDayCardVisualState shared properties

    /// Condition: .today state.
    /// Expected: fill is a tinted accent color (non-clear), border is solid (no dash), border color is todayEmphasisBorder.
    @Test("today state has tinted fill and solid border")
    func testTodayStateStyle() {
        let state = MultidayDayCardVisualState.today
        #expect(state.borderStyle.dash.isEmpty)
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

    /// Condition: each state has a distinct border color from the others.
    /// Expected: today, created, and uncreated all return different border colors.
    @Test("each state produces a distinct border color")
    func testDistinctBorderColors() {
        let today = MultidayDayCardVisualState.today.borderColor
        let created = MultidayDayCardVisualState.created.borderColor
        let uncreated = MultidayDayCardVisualState.uncreated.borderColor

        #expect(today != created)
        #expect(today != uncreated)
        #expect(created != uncreated)
    }

    /// Condition: today and created/uncreated have distinct fills.
    /// Expected: today fill differs from created/uncreated fills.
    @Test("today state has distinct fill from other states")
    func testTodayFillDistinct() {
        let todayFill = MultidayDayCardVisualState.today.fill
        let createdFill = MultidayDayCardVisualState.created.fill
        let uncreatedFill = MultidayDayCardVisualState.uncreated.fill

        #expect(todayFill != createdFill)
        #expect(todayFill != uncreatedFill)
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

    private func makeConventionalModel(today: Date) -> SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: .conventional,
            calendar: Self.calendar,
            today: today,
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )
    }

    private func makeTraditionalModel(today: Date) -> SpreadHeaderNavigatorModel {
        SpreadHeaderNavigatorModel(
            mode: .traditional,
            calendar: Self.calendar,
            today: today,
            spreads: [],
            tasks: [],
            notes: [],
            events: []
        )
    }

    private func visualState(
        isToday: Bool,
        mode: SpreadHeaderNavigatorModel.Mode,
        hasTargets: Bool,
        today: Date
    ) -> MultidayDayCardVisualState {
        if isToday { return .today }
        if mode == .traditional || hasTargets { return .created }
        return .uncreated
    }

    // MARK: - Conventional mode mapping

    /// Condition: Conventional mode, today's date.
    /// Expected: visual state is .today regardless of targets.
    @Test("Conventional mode: today date maps to .today")
    func testConventionalTodayMapsToToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: true, mode: .conventional, hasTargets: false, today: today)
        #expect(state == .today)
    }

    /// Condition: Conventional mode, non-today date with selection targets.
    /// Expected: visual state is .created.
    @Test("Conventional mode: date with targets maps to .created")
    func testConventionalWithTargetsMapsToCreated() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: false, mode: .conventional, hasTargets: true, today: today)
        #expect(state == .created)
    }

    /// Condition: Conventional mode, non-today date with no selection targets.
    /// Expected: visual state is .uncreated.
    @Test("Conventional mode: date with no targets maps to .uncreated")
    func testConventionalNoTargetsMapsToUncreated() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: false, mode: .conventional, hasTargets: false, today: today)
        #expect(state == .uncreated)
    }

    // MARK: - Traditional mode mapping

    /// Condition: Traditional mode, today's date.
    /// Expected: visual state is .today.
    @Test("Traditional mode: today date maps to .today")
    func testTraditionalTodayMapsToToday() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: true, mode: .traditional, hasTargets: false, today: today)
        #expect(state == .today)
    }

    /// Condition: Traditional mode, non-today date with no targets.
    /// Expected: visual state is .created (all traditional days are navigable).
    @Test("Traditional mode: date without targets still maps to .created")
    func testTraditionalAlwaysCreated() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: false, mode: .traditional, hasTargets: false, today: today)
        #expect(state == .created)
    }

    /// Condition: Traditional mode, non-today date with targets.
    /// Expected: visual state is .created.
    @Test("Traditional mode: date with targets maps to .created")
    func testTraditionalWithTargetsMapsToCreated() {
        let today = Self.makeDate(year: 2026, month: 4, day: 13)
        let state = visualState(isToday: false, mode: .traditional, hasTargets: true, today: today)
        #expect(state == .created)
    }
}
