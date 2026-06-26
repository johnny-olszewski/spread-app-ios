import Foundation
import Testing
@testable import Spread

struct EventSpreadIndexTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Setup: an event overlapping a day spread but not a later, unrelated day spread.
    /// Expected: `updateEvent` indexes the event only under the overlapping spread's key.
    @Test func testUpdateEventIndexesOnlyOverlappingSpreads() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let overlappingSpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let laterSpread = DataModel.Spread(
            period: .day,
            date: Self.makeDate(year: 2026, month: 1, day: 20),
            calendar: Self.calendar
        )
        let event = DataModel.Event(title: "Event", startDate: dayDate, endDate: dayDate)

        var index = EventSpreadIndex(calendar: Self.calendar)
        index.updateEvent(event, spreads: [overlappingSpread, laterSpread])

        let overlappingKey = SpreadDataModelKey(spread: overlappingSpread, calendar: Self.calendar)
        let laterKey = SpreadDataModelKey(spread: laterSpread, calendar: Self.calendar)
        #expect(index.entityIDs(for: overlappingKey) == [event.id])
        #expect(index.entityIDs(for: laterKey).isEmpty)
        #expect(index.keys(for: event.id) == [overlappingKey])
    }

    /// Setup: an event's date range changes via a second `updateEvent` call.
    /// Expected: the event's old key is dropped and the new overlapping key is added.
    @Test func testUpdateEventRecomputesMembershipOnDateChange() {
        let firstDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let secondDate = Self.makeDate(year: 2026, month: 1, day: 20)
        let firstSpread = DataModel.Spread(period: .day, date: firstDate, calendar: Self.calendar)
        let secondSpread = DataModel.Spread(period: .day, date: secondDate, calendar: Self.calendar)
        let event = DataModel.Event(title: "Event", startDate: firstDate, endDate: firstDate)

        var index = EventSpreadIndex(calendar: Self.calendar)
        index.updateEvent(event, spreads: [firstSpread, secondSpread])

        event.startDate = secondDate
        event.endDate = secondDate
        index.updateEvent(event, spreads: [firstSpread, secondSpread])

        let firstKey = SpreadDataModelKey(spread: firstSpread, calendar: Self.calendar)
        let secondKey = SpreadDataModelKey(spread: secondSpread, calendar: Self.calendar)
        #expect(index.entityIDs(for: firstKey).isEmpty)
        #expect(index.entityIDs(for: secondKey) == [event.id])
    }

    /// Setup: an indexed event is removed.
    /// Expected: it no longer appears under any spread key.
    @Test func testRemoveEventClearsAllMemberships() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let event = DataModel.Event(title: "Event", startDate: dayDate, endDate: dayDate)

        var index = EventSpreadIndex(calendar: Self.calendar)
        index.updateEvent(event, spreads: [spread])
        index.removeEvent(id: event.id)

        let key = SpreadDataModelKey(spread: spread, calendar: Self.calendar)
        #expect(index.entityIDs(for: key).isEmpty)
        #expect(index.keys(for: event.id).isEmpty)
    }

    /// Setup: two events exist (one overlapping, one not) before a new, overlapping spread
    /// is added via `addSpread`.
    /// Expected: only the overlapping event gains the new spread's key — the non-overlapping
    /// event is untouched, proving the spread-side recompute is scoped to matching events.
    @Test func testAddSpreadIndexesOnlyOverlappingEvents() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let newSpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let overlappingEvent = DataModel.Event(title: "Overlap", startDate: dayDate, endDate: dayDate)
        let nonOverlappingEvent = DataModel.Event(
            title: "Later",
            startDate: Self.makeDate(year: 2026, month: 1, day: 20),
            endDate: Self.makeDate(year: 2026, month: 1, day: 20)
        )

        var index = EventSpreadIndex(calendar: Self.calendar)
        index.addSpread(newSpread, events: [overlappingEvent, nonOverlappingEvent])

        let key = SpreadDataModelKey(spread: newSpread, calendar: Self.calendar)
        #expect(index.entityIDs(for: key) == [overlappingEvent.id])
        #expect(index.keys(for: nonOverlappingEvent.id).isEmpty)
    }

    /// Setup: a spread with two overlapping events plus an unrelated spread/event pair.
    /// Expected: `removeSpread` clears only the deleted spread's bucket — the unrelated
    /// spread's event membership is untouched.
    @Test func testRemoveSpreadClearsOnlyThatSpreadsMemberships() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let removedSpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let unrelatedDate = Self.makeDate(year: 2026, month: 2, day: 1)
        let unrelatedSpread = DataModel.Spread(period: .month, date: unrelatedDate, calendar: Self.calendar)
        let removedSpreadEvent = DataModel.Event(title: "On removed", startDate: dayDate, endDate: dayDate)
        let unrelatedEvent = DataModel.Event(title: "On unrelated", startDate: unrelatedDate, endDate: unrelatedDate)

        var index = EventSpreadIndex(calendar: Self.calendar)
        index.updateEvent(removedSpreadEvent, spreads: [removedSpread, unrelatedSpread])
        index.updateEvent(unrelatedEvent, spreads: [removedSpread, unrelatedSpread])

        index.removeSpread(removedSpread)

        let removedKey = SpreadDataModelKey(spread: removedSpread, calendar: Self.calendar)
        let unrelatedKey = SpreadDataModelKey(spread: unrelatedSpread, calendar: Self.calendar)
        #expect(index.entityIDs(for: removedKey).isEmpty)
        #expect(index.entityIDs(for: unrelatedKey) == [unrelatedEvent.id])
        #expect(index.keys(for: removedSpreadEvent.id).isEmpty)
    }

    /// Setup: an overlapping event (its date falls within both the day spread's date and
    /// the multiday spread's range) and an out-of-range event, indexed via `updateEvent`
    /// against a full spread list.
    /// Expected: the overlapping event appears in both spreads' buckets; the out-of-range
    /// event appears in neither.
    @Test func testEventIndexMembershipMatchesExpectedOverlap() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 11),
            endDate: Self.makeDate(year: 2026, month: 1, day: 13),
            calendar: Self.calendar
        )
        let overlappingEvent = DataModel.Event(title: "Overlap", startDate: dayDate, endDate: dayDate)
        let outOfRangeEvent = DataModel.Event(
            title: "Later",
            startDate: Self.makeDate(year: 2026, month: 1, day: 20),
            endDate: Self.makeDate(year: 2026, month: 1, day: 20)
        )
        let events = [overlappingEvent, outOfRangeEvent]
        let spreads = [daySpread, multidaySpread]

        var index = EventSpreadIndex(calendar: Self.calendar)
        for event in events {
            index.updateEvent(event, spreads: spreads)
        }

        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let multidayKey = SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)

        #expect(index.entityIDs(for: dayKey) == Set([overlappingEvent.id]))
        #expect(index.entityIDs(for: multidayKey) == Set([overlappingEvent.id]))
    }
}
