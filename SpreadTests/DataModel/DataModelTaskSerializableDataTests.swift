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

    /// Conditions: A task with both `scheduledTime` and `scheduledTimeUpdatedAt` set, serialized
    /// then decoded back via `ServerEntryRow`/`SyncSerializer.createTask`. The push payload
    /// carries no server-assigned `revision`, so one is injected before decoding, mimicking
    /// what the server adds to every returned row.
    /// Expected: The round trip is lossless — `scheduledTime` is encoded as a full timestamptz
    /// (via `SyncDateFormatting.formatTimestamp`, matching `created_at`/`updated_at` style, not the
    /// day-only `due_date` style) and decodes back to the same instant.
    @Test func testScheduledTimeRoundTripsThroughSerializeAndDecode() throws {
        let timestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!
        let scheduledTime = SyncDateFormatting.parseTimestamp("2025-06-01T14:30:00.000Z")!
        let scheduledTimeUpdatedAt = SyncDateFormatting.parseTimestamp("2025-06-01T09:00:00.000Z")!
        let task = DataModel.Task(
            title: "Dentist appointment",
            scheduledTime: scheduledTime,
            scheduledTimeUpdatedAt: scheduledTimeUpdatedAt
        )

        let data = try #require(task.serialize(deviceId: deviceId, timestamp: timestamp, deletedAt: nil))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Encoded using the full-timestamp formatter (fractional seconds + "Z"), not the
        // yyyy-MM-dd date-only formatter used for `due_date`.
        #expect(json["scheduled_time"] as? String == SyncDateFormatting.formatTimestamp(scheduledTime))
        #expect(json["scheduled_time_updated_at"] as? String == SyncDateFormatting.formatTimestamp(scheduledTimeUpdatedAt))

        let row = try JSONDecoder().decode(ServerEntryRow.self, from: serverRowData(from: json))
        let decodedTask = try #require(SyncSerializer.createTask(from: row))
        #expect(decodedTask.scheduledTime == scheduledTime)
    }

    /// Conditions: A task with no `scheduledTime`/`scheduledTimeUpdatedAt` (both nil), serialized
    /// then decoded back via `ServerEntryRow`/`SyncSerializer.createTask` (with the
    /// server-assigned `revision` injected, as above).
    /// Expected: `scheduled_time` encodes as JSON null and the decoded task's `scheduledTime`
    /// round-trips to nil — no time is fabricated for an untimed task.
    @Test func testNilScheduledTimeRoundTripsToNil() throws {
        let timestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!
        let task = DataModel.Task(title: "No time set")

        let data = try #require(task.serialize(deviceId: deviceId, timestamp: timestamp, deletedAt: nil))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["scheduled_time"] is NSNull)

        let row = try JSONDecoder().decode(ServerEntryRow.self, from: serverRowData(from: json))
        let decodedTask = try #require(SyncSerializer.createTask(from: row))
        #expect(decodedTask.scheduledTime == nil)
    }

    /// Rebuilds a push payload as a server row by adding the server-assigned `revision`
    /// field `ServerEntryRow` requires.
    private func serverRowData(from pushJSON: [String: Any]) -> Data {
        var json = pushJSON
        json["revision"] = 1
        return try! JSONSerialization.data(withJSONObject: json)
    }
}
