import Foundation
import Testing
@testable import Spread

struct DataModelTaskSerializableDataTests {

    private let deviceId = UUID()

    /// Conditions: `DataModel.Task`'s static entity-type lookup.
    /// Expected: Returns `.entry` — Task and Note share the server `entries` table/RPC,
    /// there is no separate `.task` case on `SyncEntityType`.
    @Test func testEntityTypeIsEntry() {
        #expect(DataModel.Task.entityType == .entry)
    }

    /// Conditions: A fully-populated task with per-field LWW timestamps and no deletion.
    /// Expected: `Task.serialize` produces byte-identical JSON to `SyncSerializer.serializeTaskEntry`
    /// for the same input.
    @Test func testSerializeMatchesSyncSerializerForPopulatedTask() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!
        let task = DataModel.Task(
            title: "Buy groceries",
            body: "Milk, eggs, bread",
            priority: .high,
            dueDate: SyncDateFormatting.parseDate("2025-06-01"),
            date: SyncDateFormatting.parseDate("2025-05-01"),
            period: .day,
            titleUpdatedAt: modelTimestamp,
            dateUpdatedAt: modelTimestamp,
            periodUpdatedAt: modelTimestamp,
            statusUpdatedAt: modelTimestamp,
            bodyUpdatedAt: modelTimestamp,
            priorityUpdatedAt: modelTimestamp,
            dueDateUpdatedAt: modelTimestamp
        )

        let legacyData = SyncSerializer.serializeTaskEntry(task, deviceId: deviceId, timestamp: fallbackTimestamp)
        let newData = task.serialize(deviceId: deviceId, timestamp: fallbackTimestamp, deletedAt: nil)

        let legacyJSON = try JSONSerialization.jsonObject(with: legacyData!) as! NSDictionary
        let newJSON = try JSONSerialization.jsonObject(with: newData!) as! NSDictionary
        #expect(legacyJSON == newJSON)
    }

    /// Conditions: A task with no per-field LWW timestamps (all nil) and no deletion.
    /// Expected: `Task.serialize` matches `SyncSerializer.serializeTaskEntry`'s fallback-timestamp
    /// behavior exactly.
    @Test func testSerializeMatchesSyncSerializerForTaskWithoutMetadata() throws {
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!
        let task = DataModel.Task(title: "Test")

        let legacyData = SyncSerializer.serializeTaskEntry(task, deviceId: deviceId, timestamp: fallbackTimestamp)
        let newData = task.serialize(deviceId: deviceId, timestamp: fallbackTimestamp, deletedAt: nil)

        let legacyJSON = try JSONSerialization.jsonObject(with: legacyData!) as! NSDictionary
        let newJSON = try JSONSerialization.jsonObject(with: newData!) as! NSDictionary
        #expect(legacyJSON == newJSON)
    }

    /// Conditions: A task deletion mutation, with an explicit `deletedAt` override.
    /// Expected: `Task.serialize` matches `SyncSerializer.serializeTaskEntry`'s deletion handling
    /// exactly, including the overridden `deleted_at` value.
    @Test func testSerializeMatchesSyncSerializerForDeletedTask() throws {
        let timestamp = SyncDateFormatting.parseTimestamp("2025-06-15T12:00:00.000Z")!
        let deletedAt = SyncDateFormatting.parseTimestamp("2025-06-16T08:30:00.000Z")!
        let task = DataModel.Task(title: "Deleted task")

        let legacyData = SyncSerializer.serializeTaskEntry(
            task, deviceId: deviceId, timestamp: timestamp, deletedAt: deletedAt
        )
        let newData = task.serialize(deviceId: deviceId, timestamp: timestamp, deletedAt: deletedAt)

        let legacyJSON = try JSONSerialization.jsonObject(with: legacyData!) as! NSDictionary
        let newJSON = try JSONSerialization.jsonObject(with: newData!) as! NSDictionary
        #expect(legacyJSON == newJSON)
    }

    /// Conditions: A task whose preferred assignment (date/period) has been cleared.
    /// Expected: `Task.serialize` matches `SyncSerializer.serializeTaskEntry`'s null-encoding
    /// of the cleared fields exactly.
    @Test func testSerializeMatchesSyncSerializerForClearedPreferredAssignment() throws {
        let timestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!
        let task = DataModel.Task(title: "Unassigned", date: nil, period: nil)

        let legacyData = SyncSerializer.serializeTaskEntry(task, deviceId: deviceId, timestamp: timestamp)
        let newData = task.serialize(deviceId: deviceId, timestamp: timestamp, deletedAt: nil)

        let legacyJSON = try JSONSerialization.jsonObject(with: legacyData!) as! NSDictionary
        let newJSON = try JSONSerialization.jsonObject(with: newData!) as! NSDictionary
        #expect(legacyJSON == newJSON)
    }
}
