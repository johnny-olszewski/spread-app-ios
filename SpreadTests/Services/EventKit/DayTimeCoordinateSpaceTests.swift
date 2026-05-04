import Foundation
import SwiftUI
import Testing
@testable import Spread

/// Tests for the overlap-offset algorithm used by `DayTimelineView`.
///
/// These tests exercise the greedy depth-counting logic directly, using
/// `SpreadDayTimelineProvider` as the concrete provider so the date accessors
/// are verified alongside the algorithm.
@MainActor
struct DayTimelineOverlapTests {

    // MARK: - Helpers

    private let calendar = Calendar.current
    private var today: Date { Date() }

    private func makeEvent(id: String, startHour: Int, endHour: Int) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: id,
            startDate: calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: today)!,
            endDate: calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: today)!,
            isAllDay: false,
            calendarTitle: "Test",
            calendarColor: .blue
        )
    }

    /// Greedy overlap-depth algorithm mirroring `DayTimelineView.layoutContexts`.
    private func overlapOffsets(for events: [CalendarEvent]) -> [CGFloat] {
        let provider = SpreadDayTimelineProvider()
        let sorted = events.sorted { provider.startDate(for: $0) < provider.startDate(for: $1) }
        var offsets: [CGFloat] = []

        for event in sorted {
            let eStart = provider.startDate(for: event)
            let eEnd = provider.endDate(for: event)
            let depth = offsets.indices.filter { i in
                let prior = sorted[i]
                let pStart = provider.startDate(for: prior)
                let pEnd = provider.endDate(for: prior)
                return pStart < eEnd && pEnd > eStart
            }.count
            offsets.append(CGFloat(depth) * 12)
        }

        return offsets
    }

    // MARK: - Tests

    /// Conditions: Two non-overlapping events (morning and afternoon, no time intersection).
    /// Expected: Both events get overlapOffset 0.
    @Test func testNonOverlappingEventsHaveZeroOffset() {
        let morning = makeEvent(id: "a", startHour: 9, endHour: 10)
        let afternoon = makeEvent(id: "b", startHour: 14, endHour: 15)

        let offsets = overlapOffsets(for: [morning, afternoon])

        #expect(offsets[0] == 0)
        #expect(offsets[1] == 0)
    }

    /// Conditions: Two events whose time ranges overlap.
    /// Expected: First event gets offset 0; second (later start) gets offset 12.
    @Test func testTwoOverlappingEventsGetEscalatingOffsets() {
        let first = makeEvent(id: "a", startHour: 9, endHour: 11)
        let second = makeEvent(id: "b", startHour: 10, endHour: 12)

        let offsets = overlapOffsets(for: [first, second])

        #expect(offsets[0] == 0)
        #expect(offsets[1] == 12)
    }

    /// Conditions: Three events all with overlapping time ranges.
    /// Expected: Offsets escalate 0, 12, 24.
    @Test func testThreeWayOverlapProducesEscalatingOffsets() {
        let a = makeEvent(id: "a", startHour: 9, endHour: 12)
        let b = makeEvent(id: "b", startHour: 10, endHour: 13)
        let c = makeEvent(id: "c", startHour: 11, endHour: 14)

        let offsets = overlapOffsets(for: [a, b, c])

        #expect(offsets[0] == 0)
        #expect(offsets[1] == 12)
        #expect(offsets[2] == 24)
    }

    /// Conditions: Two pairs of non-overlapping events where each pair overlaps within itself.
    /// Expected: First in each pair gets 0; second in each pair gets 12.
    @Test func testTwoPairsOfOverlappingEventsGetCorrectOffsets() {
        let a = makeEvent(id: "a", startHour: 9, endHour: 11)
        let b = makeEvent(id: "b", startHour: 10, endHour: 12)
        let c = makeEvent(id: "c", startHour: 14, endHour: 16)
        let d = makeEvent(id: "d", startHour: 15, endHour: 17)

        let offsets = overlapOffsets(for: [a, b, c, d])

        #expect(offsets[0] == 0)
        #expect(offsets[1] == 12)
        #expect(offsets[2] == 0)
        #expect(offsets[3] == 12)
    }

    // MARK: - SpreadDayTimelineProvider date accessors

    /// Conditions: Provider given a CalendarEvent.
    /// Expected: startDate and endDate forward the event's own values.
    @Test func testProviderDateAccessorsForwardEventDates() {
        let provider = SpreadDayTimelineProvider()
        let event = makeEvent(id: "x", startHour: 8, endHour: 9)

        #expect(provider.startDate(for: event) == event.startDate)
        #expect(provider.endDate(for: event) == event.endDate)
    }
}
