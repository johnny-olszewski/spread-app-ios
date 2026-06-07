import Foundation
import SwiftUI
import Testing
import JohnnyOFoundationCore
@testable import Spread

/// Tests for the column-partitioning algorithm and minimum height floor in `DayTimelineView`.
///
/// The algorithm is tested indirectly via `MockDayTimelineContentGenerator` which drives
/// a `DayTimelineView` in isolation. Because `DayTimelineView` is a SwiftUI view, layout
/// context values are extracted from its `layoutContexts` computed property — exposed via
/// a package-internal test helper.
///
/// These tests focus on the pure algorithmic logic: column assignment, total column count,
/// and height clamping. Visual rendering is covered by manual inspection.
@Suite("DayTimeline Column Layout Tests")
struct DayTimelineColumnLayoutTests {

    // MARK: - Helpers

    private static var testCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }

    private static var referenceDate: Date {
        testCalendar.date(from: DateComponents(year: 2026, month: 6, day: 5))!
    }

    private func makeEvent(
        id: String,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0
    ) -> CalendarEvent {
        let cal = Self.testCalendar
        let date = Self.referenceDate
        let start = cal.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date)!
        let end   = cal.date(bySettingHour: endHour,   minute: endMinute,   second: 0, of: date)!
        return CalendarEvent(
            id: id,
            title: id,
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarTitle: "Test",
            calendarColor: .blue
        )
    }

    // MARK: - Column assignment

    // Conditions: A single non-overlapping event is passed to the layout engine.
    // Expected: columnIndex = 0, columnCount = 1.
    @Test func testSingleEventGetsSingleColumn() {
        let event = makeEvent(id: "A", startHour: 9, endHour: 10)
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [event],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 1)
        #expect(contexts[0].columnIndex == 0)
        #expect(contexts[0].columnCount == 1)
    }

    // Conditions: Two fully-overlapping events (same start and end time).
    // Expected: columnCount = 2; one event gets columnIndex 0, the other gets columnIndex 1.
    @Test func testTwoOverlappingEventsGetTwoColumns() {
        let a = makeEvent(id: "A", startHour: 9, endHour: 10)
        let b = makeEvent(id: "B", startHour: 9, endHour: 10)
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [a, b],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 2)
        let columnCounts = Set(contexts.map(\.columnCount))
        #expect(columnCounts == [2])
        let columnIndices = Set(contexts.map(\.columnIndex))
        #expect(columnIndices == [0, 1])
    }

    // Conditions: Two sequential non-overlapping events (A ends before B starts).
    // Expected: both get columnCount = 1, each at columnIndex 0.
    @Test func testTwoSequentialEventsEachGetSingleColumn() {
        let a = makeEvent(id: "A", startHour: 9, endHour: 10)
        let b = makeEvent(id: "B", startHour: 10, endHour: 11)
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [a, b],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 2)
        #expect(contexts.allSatisfy { $0.columnCount == 1 })
        #expect(contexts.allSatisfy { $0.columnIndex == 0 })
    }

    // Conditions: Three events where A overlaps B, B overlaps C, but A and C do NOT overlap.
    // Expected: A and C can share column 0; B gets column 1. columnCount = 2 for all three.
    @Test func testChainOverlapThreeEvents() {
        let a = makeEvent(id: "A", startHour: 9, endHour: 10, endMinute: 30)   // 9:00–10:30
        let b = makeEvent(id: "B", startHour: 10, endHour: 11, endMinute: 30)  // 10:00–11:30
        let c = makeEvent(id: "C", startHour: 11, endHour: 12)                 // 11:00–12:00
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [a, b, c],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 3)
        // All three are in the same cluster (chain overlap), so columnCount = 2
        #expect(contexts.allSatisfy { $0.columnCount == 2 })
        // A gets col 0, B gets col 1, C gets col 0 (col 0 free again after A ends at 10:30)
        let byID = Dictionary(uniqueKeysWithValues: contexts.map { ($0.item.id, $0.columnIndex) })
        #expect(byID["A"] == 0)
        #expect(byID["B"] == 1)
        #expect(byID["C"] == 0)
    }

    // MARK: - Minimum height floor

    // Conditions: An event shorter than 30 minutes in a tall coordinate space.
    // Expected: context.height == 44 (the minimum floor).
    @Test func testShortEventGetsMinimumHeight() {
        let event = makeEvent(id: "Short", startHour: 9, startMinute: 0, endHour: 9, endMinute: 15)
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [event],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(height: 2000),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 1)
        #expect(contexts[0].height == 44)
    }

    // Conditions: An event exactly 60 minutes long in a tall coordinate space
    // where the proportional height exceeds the minimum.
    // Expected: context.height > 44 (proportional, not clamped).
    @Test func testLongEventGetsProportionalHeight() {
        let event = makeEvent(id: "Long", startHour: 9, endHour: 10)  // 60 min
        let contexts = DayTimelineLayoutEngine.layoutContexts(
            items: [event],
            startDate: { $0.startDate },
            endDate: { $0.endDate },
            isAllDay: { _ in false },
            coordinateSpace: makeCoordinateSpace(height: 2000),
            minimumEventHeight: 44,
            minimumHeightThresholdSeconds: 30 * 60
        )

        #expect(contexts.count == 1)
        #expect(contexts[0].height > 44)
    }

    // MARK: - Helpers

    private func makeCoordinateSpace(height: CGFloat = 1000) -> DayTimeCoordinateSpace {
        let cal = Self.testCalendar
        let date = Self.referenceDate
        let start = cal.date(bySettingHour: 0, minute: 0, second: 0, of: date)!
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        return DayTimeCoordinateSpace(visibleStart: start, visibleEnd: end, totalHeight: height)
    }
}
