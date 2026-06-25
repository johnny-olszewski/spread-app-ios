import Foundation
import Testing
@testable import Spread

struct SpreadKeyIndexTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Setup: a single entity is updated with a non-empty key set on an empty index.
    /// Expected: the entity is retrievable via both forward (key → ID) and reverse
    /// (ID → keys) lookups.
    @Test func testUpdateInsertsEntityIntoForwardAndReverseLookups() {
        var index = SpreadKeyIndex()
        let entityID = UUID()
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let key = SpreadDataModelKey(period: .day, date: dayDate, calendar: Self.calendar)

        index.update(entityID: entityID, keys: [key])

        #expect(index.entityIDs(for: key) == [entityID])
        #expect(index.keys(for: entityID) == [key])
    }

    /// Setup: an entity moves from one key to a different key via a second `update` call.
    /// Expected: the entity is removed from the stale bucket and added to the new one —
    /// only those two buckets are touched.
    @Test func testUpdateMovesEntityBetweenBucketsOnKeyChange() {
        var index = SpreadKeyIndex()
        let entityID = UUID()
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let oldKey = SpreadDataModelKey(period: .day, date: dayDate, calendar: Self.calendar)
        let newKey = SpreadDataModelKey(period: .month, date: dayDate, calendar: Self.calendar)

        index.update(entityID: entityID, keys: [oldKey])
        index.update(entityID: entityID, keys: [newKey])

        #expect(index.entityIDs(for: oldKey).isEmpty)
        #expect(index.entityIDs(for: newKey) == [entityID])
        #expect(index.keys(for: entityID) == [newKey])
    }

    /// Setup: two unrelated entities are indexed under different keys; one is then updated.
    /// Expected: the unrelated entity's bucket membership is completely untouched by the
    /// other entity's update — proving the update is scoped to the changed entity only,
    /// not a full rebuild.
    @Test func testUpdatingOneEntityDoesNotAffectAnUnrelatedEntity() {
        var index = SpreadKeyIndex()
        let changedID = UUID()
        let unrelatedID = UUID()
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let monthDate = Self.makeDate(year: 2026, month: 2, day: 1)
        let dayKey = SpreadDataModelKey(period: .day, date: dayDate, calendar: Self.calendar)
        let monthKey = SpreadDataModelKey(period: .month, date: monthDate, calendar: Self.calendar)
        let yearKey = SpreadDataModelKey(period: .year, date: dayDate, calendar: Self.calendar)

        index.update(entityID: changedID, keys: [dayKey])
        index.update(entityID: unrelatedID, keys: [monthKey])

        index.update(entityID: changedID, keys: [yearKey])

        #expect(index.entityIDs(for: monthKey) == [unrelatedID])
        #expect(index.keys(for: unrelatedID) == [monthKey])
        #expect(index.entityIDs(for: dayKey).isEmpty)
        #expect(index.entityIDs(for: yearKey) == [changedID])
    }

    /// Setup: an entity indexed under two keys is fully removed.
    /// Expected: both bucket memberships are dropped and the reverse lookup is empty.
    @Test func testRemoveClearsAllBucketMembershipsForEntity() {
        var index = SpreadKeyIndex()
        let entityID = UUID()
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let dayKey = SpreadDataModelKey(period: .day, date: dayDate, calendar: Self.calendar)
        let monthKey = SpreadDataModelKey(period: .month, date: dayDate, calendar: Self.calendar)
        index.update(entityID: entityID, keys: [dayKey, monthKey])

        index.remove(entityID: entityID)

        #expect(index.entityIDs(for: dayKey).isEmpty)
        #expect(index.entityIDs(for: monthKey).isEmpty)
        #expect(index.keys(for: entityID).isEmpty)
    }

    /// Setup: multiple tasks with current and migrated-history assignments are indexed via
    /// `JournalRuleEngine.spreadKeys` (the same key computation the legacy builder uses).
    /// Expected: the index's forward lookup for each spread matches exactly the set of
    /// tasks `JournalRuleEngine.buildDataModel` would place there directly — proving the
    /// incremental index produces identical membership to a full rebuild.
    @Test func testIndexMembershipMatchesFullRebuildForTasks() {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let multidaySpread = DataModel.Spread(
            startDate: Self.makeDate(year: 2026, month: 1, day: 10),
            endDate: Self.makeDate(year: 2026, month: 1, day: 12),
            calendar: Self.calendar
        )
        let dayTask = DataModel.Task(
            title: "Day",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let multidayTask = DataModel.Task(
            title: "Multiday",
            date: taskDate,
            period: .multiday,
            assignments: [
                Assignment(period: .multiday, date: multidaySpread.date, spreadID: multidaySpread.id, status: .open)
            ]
        )
        let migratedTask = DataModel.Task(
            title: "Migrated",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .migrated)]
        )
        let tasks = [dayTask, multidayTask, migratedTask]
        let spreads = [daySpread, multidaySpread]

        let engine = JournalRuleEngine(calendar: Self.calendar)
        var index = SpreadKeyIndex()
        for task in tasks {
            index.update(entityID: task.id, keys: engine.spreadKeys(for: task, spreads: spreads))
        }

        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let multidayKey = SpreadDataModelKey(spread: multidaySpread, calendar: Self.calendar)

        let legacyDayModel = engine.buildDataModel(spreads: spreads, tasks: tasks, notes: [], events: [])[key: dayKey]
        let legacyMultidayModel = engine.buildDataModel(
            spreads: spreads,
            tasks: tasks,
            notes: [],
            events: []
        )[key: multidayKey]

        #expect(index.entityIDs(for: dayKey) == Set(legacyDayModel?.tasks.map(\.id) ?? []))
        #expect(index.entityIDs(for: multidayKey) == Set(legacyMultidayModel?.tasks.map(\.id) ?? []))
    }
}
