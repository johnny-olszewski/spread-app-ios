import Foundation
import SwiftData
import Testing
@testable import Spread

struct SyncMetadataTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var referenceDate: Date {
        SyncDateFormatting.parseTimestamp("2025-06-15T12:00:00.000Z")!
    }

    private var deviceId: UUID {
        UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    }

    // MARK: - Spread Sync Metadata

    /// Conditions: Create a spread with default sync metadata.
    /// Expected: deletedAt and deviceId should be nil, revision should be 0,
    /// all LWW timestamps should be nil.
    @MainActor
    @Test func testSpreadDefaultSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let spread = DataModel.Spread(period: .day, date: referenceDate, calendar: testCalendar)
        context.insert(spread)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Spread>()).first!
        #expect(fetched.deletedAt == nil)
        #expect(fetched.deviceId == nil)
        #expect(fetched.revision == 0)
        #expect(fetched.periodUpdatedAt == nil)
        #expect(fetched.dateUpdatedAt == nil)
        #expect(fetched.startDateUpdatedAt == nil)
        #expect(fetched.endDateUpdatedAt == nil)
    }

    /// Conditions: Create a spread with explicit sync metadata values.
    /// Expected: All sync metadata fields should round-trip through SwiftData.
    @MainActor
    @Test func testSpreadExplicitSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date.now

        let spread = DataModel.Spread(
            period: .month,
            date: referenceDate,
            calendar: testCalendar,
            deletedAt: now,
            deviceId: deviceId,
            revision: 42,
            periodUpdatedAt: now,
            dateUpdatedAt: now,
            startDateUpdatedAt: now,
            endDateUpdatedAt: now
        )
        context.insert(spread)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Spread>()).first!
        #expect(fetched.deletedAt != nil)
        #expect(fetched.deviceId == deviceId)
        #expect(fetched.revision == 42)
        #expect(fetched.periodUpdatedAt != nil)
        #expect(fetched.dateUpdatedAt != nil)
        #expect(fetched.startDateUpdatedAt != nil)
        #expect(fetched.endDateUpdatedAt != nil)
    }

    // MARK: - Task Sync Metadata

    /// Conditions: Create a task with default sync metadata.
    /// Expected: deletedAt and deviceId should be nil, revision should be 0,
    /// all LWW timestamps should be nil.
    @MainActor
    @Test func testTaskDefaultSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let task = DataModel.Task(title: "Test task")
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Task>()).first!
        #expect(fetched.deletedAt == nil)
        #expect(fetched.deviceId == nil)
        #expect(fetched.revision == 0)
        #expect(fetched.titleUpdatedAt == nil)
        #expect(fetched.dateUpdatedAt == nil)
        #expect(fetched.periodUpdatedAt == nil)
        #expect(fetched.statusUpdatedAt == nil)
    }

    /// Conditions: Create a task with explicit sync metadata values.
    /// Expected: All sync metadata fields should round-trip through SwiftData.
    @MainActor
    @Test func testTaskExplicitSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date.now

        let task = DataModel.Task(
            title: "Test task",
            deletedAt: now,
            deviceId: deviceId,
            revision: 7,
            titleUpdatedAt: now,
            dateUpdatedAt: now,
            periodUpdatedAt: now,
            statusUpdatedAt: now
        )
        context.insert(task)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Task>()).first!
        #expect(fetched.deletedAt != nil)
        #expect(fetched.deviceId == deviceId)
        #expect(fetched.revision == 7)
        #expect(fetched.titleUpdatedAt != nil)
        #expect(fetched.dateUpdatedAt != nil)
        #expect(fetched.periodUpdatedAt != nil)
        #expect(fetched.statusUpdatedAt != nil)
    }

    // MARK: - Event Sync Metadata

    /// Conditions: Create an event with default sync metadata.
    /// Expected: deletedAt and deviceId should be nil, revision should be 0,
    /// all LWW timestamps should be nil.
    @MainActor
    @Test func testEventDefaultSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let event = DataModel.Event(title: "Test event")
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Event>()).first!
        #expect(fetched.deletedAt == nil)
        #expect(fetched.deviceId == nil)
        #expect(fetched.revision == 0)
        #expect(fetched.titleUpdatedAt == nil)
        #expect(fetched.timingUpdatedAt == nil)
        #expect(fetched.startDateUpdatedAt == nil)
        #expect(fetched.endDateUpdatedAt == nil)
        #expect(fetched.startTimeUpdatedAt == nil)
        #expect(fetched.endTimeUpdatedAt == nil)
    }

    /// Conditions: Create an event with explicit sync metadata values.
    /// Expected: All sync metadata fields should round-trip through SwiftData.
    @MainActor
    @Test func testEventExplicitSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date.now

        let event = DataModel.Event(
            title: "Test event",
            deletedAt: now,
            deviceId: deviceId,
            revision: 3,
            titleUpdatedAt: now,
            timingUpdatedAt: now,
            startDateUpdatedAt: now,
            endDateUpdatedAt: now,
            startTimeUpdatedAt: now,
            endTimeUpdatedAt: now
        )
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Event>()).first!
        #expect(fetched.deletedAt != nil)
        #expect(fetched.deviceId == deviceId)
        #expect(fetched.revision == 3)
        #expect(fetched.titleUpdatedAt != nil)
        #expect(fetched.timingUpdatedAt != nil)
        #expect(fetched.startDateUpdatedAt != nil)
        #expect(fetched.endDateUpdatedAt != nil)
        #expect(fetched.startTimeUpdatedAt != nil)
        #expect(fetched.endTimeUpdatedAt != nil)
    }

    // MARK: - Note Sync Metadata

    /// Conditions: Create a note with default sync metadata.
    /// Expected: deletedAt and deviceId should be nil, revision should be 0,
    /// all LWW timestamps should be nil.
    @MainActor
    @Test func testNoteDefaultSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let note = DataModel.Note(title: "Test note")
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Note>()).first!
        #expect(fetched.deletedAt == nil)
        #expect(fetched.deviceId == nil)
        #expect(fetched.revision == 0)
        #expect(fetched.titleUpdatedAt == nil)
        #expect(fetched.contentUpdatedAt == nil)
        #expect(fetched.dateUpdatedAt == nil)
        #expect(fetched.periodUpdatedAt == nil)
        #expect(fetched.statusUpdatedAt == nil)
    }

    /// Conditions: Create a note with explicit sync metadata values.
    /// Expected: All sync metadata fields should round-trip through SwiftData.
    @MainActor
    @Test func testNoteExplicitSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date.now

        let note = DataModel.Note(
            title: "Test note",
            deletedAt: now,
            deviceId: deviceId,
            revision: 15,
            titleUpdatedAt: now,
            contentUpdatedAt: now,
            dateUpdatedAt: now,
            periodUpdatedAt: now,
            statusUpdatedAt: now
        )
        context.insert(note)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Note>()).first!
        #expect(fetched.deletedAt != nil)
        #expect(fetched.deviceId == deviceId)
        #expect(fetched.revision == 15)
        #expect(fetched.titleUpdatedAt != nil)
        #expect(fetched.contentUpdatedAt != nil)
        #expect(fetched.dateUpdatedAt != nil)
        #expect(fetched.periodUpdatedAt != nil)
        #expect(fetched.statusUpdatedAt != nil)
    }

    // MARK: - Collection Sync Metadata

    /// Conditions: Create a collection with default sync metadata.
    /// Expected: deletedAt and deviceId should be nil, revision should be 0,
    /// titleUpdatedAt should be nil.
    @MainActor
    @Test func testCollectionDefaultSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext

        let collection = DataModel.Collection(title: "Test collection")
        context.insert(collection)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Collection>()).first!
        #expect(fetched.deletedAt == nil)
        #expect(fetched.deviceId == nil)
        #expect(fetched.revision == 0)
        #expect(fetched.titleUpdatedAt == nil)
    }

    /// Conditions: Create a collection with explicit sync metadata values.
    /// Expected: All sync metadata fields should round-trip through SwiftData.
    @MainActor
    @Test func testCollectionExplicitSyncMetadata() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let now = Date.now

        let collection = DataModel.Collection(
            title: "Test collection",
            deletedAt: now,
            deviceId: deviceId,
            revision: 99,
            titleUpdatedAt: now
        )
        context.insert(collection)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<DataModel.Collection>()).first!
        #expect(fetched.deletedAt != nil)
        #expect(fetched.deviceId == deviceId)
        #expect(fetched.revision == 99)
        #expect(fetched.titleUpdatedAt != nil)
    }

    // MARK: - Assignment statusUpdatedAt

    /// Conditions: Encode and decode a TaskAssignment with statusUpdatedAt set.
    /// Expected: statusUpdatedAt should round-trip through Codable.
    @Test func testTaskAssignmentStatusUpdatedAtRoundTrips() throws {
        let now = Date.now
        let assignment = TaskAssignment(
            period: .day,
            date: referenceDate,
            status: .open,
            statusUpdatedAt: now
        )

        let data = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(TaskAssignment.self, from: data)

        #expect(decoded.statusUpdatedAt != nil)
        #expect(decoded.period == .day)
        #expect(decoded.status == .open)
    }

    /// Conditions: Encode and decode a TaskAssignment without statusUpdatedAt.
    /// Expected: statusUpdatedAt should default to nil after decoding.
    @Test func testTaskAssignmentStatusUpdatedAtDefaultsToNil() throws {
        let assignment = TaskAssignment(
            period: .month,
            date: referenceDate,
            status: .complete
        )

        let data = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(TaskAssignment.self, from: data)

        #expect(decoded.statusUpdatedAt == nil)
    }

    /// Conditions: Encode and decode a NoteAssignment with statusUpdatedAt set.
    /// Expected: statusUpdatedAt should round-trip through Codable.
    @Test func testNoteAssignmentStatusUpdatedAtRoundTrips() throws {
        let now = Date.now
        let assignment = NoteAssignment(
            period: .day,
            date: referenceDate,
            status: .active,
            statusUpdatedAt: now
        )

        let data = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(NoteAssignment.self, from: data)

        #expect(decoded.statusUpdatedAt != nil)
        #expect(decoded.period == .day)
        #expect(decoded.status == .active)
    }

    /// Conditions: Encode and decode a NoteAssignment without statusUpdatedAt.
    /// Expected: statusUpdatedAt should default to nil after decoding.
    @Test func testNoteAssignmentStatusUpdatedAtDefaultsToNil() throws {
        let assignment = NoteAssignment(
            period: .year,
            date: referenceDate,
            status: .migrated
        )

        let data = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(NoteAssignment.self, from: data)

        #expect(decoded.statusUpdatedAt == nil)
    }

    // MARK: - SyncSerializer Metadata Usage

    /// Conditions: Serialize a spread that has per-field LWW timestamps set.
    /// Expected: Serialized JSON should use the model's timestamps, not the fallback.
    @Test func testSerializerUsesSpreadModelMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let spread = DataModel.Spread(
            period: .day,
            date: referenceDate,
            calendar: testCalendar,
            periodUpdatedAt: modelTimestamp,
            dateUpdatedAt: modelTimestamp,
            startDateUpdatedAt: modelTimestamp,
            endDateUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeSpread(spread, deviceId: deviceId, timestamp: fallbackTimestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["period_updated_at"] as? String == expectedTs)
        #expect(json["date_updated_at"] as? String == expectedTs)
        #expect(json["start_date_updated_at"] as? String == expectedTs)
        #expect(json["end_date_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a spread that has no per-field LWW timestamps (all nil).
    /// Expected: Serialized JSON should fall back to the provided timestamp.
    @Test func testSerializerFallsBackForSpreadWithoutMetadata() throws {
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let spread = DataModel.Spread(
            period: .day,
            date: referenceDate,
            calendar: testCalendar
        )

        let data = SyncSerializer.serializeSpread(spread, deviceId: deviceId, timestamp: fallbackTimestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(fallbackTimestamp)
        #expect(json["period_updated_at"] as? String == expectedTs)
        #expect(json["date_updated_at"] as? String == expectedTs)
        #expect(json["start_date_updated_at"] as? String == expectedTs)
        #expect(json["end_date_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a task that has per-field LWW timestamps set.
    /// Expected: Serialized JSON should use the model's timestamps, not the fallback.
    @Test func testSerializerUsesTaskModelMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let task = DataModel.Task(
            title: "Test",
            titleUpdatedAt: modelTimestamp,
            dateUpdatedAt: modelTimestamp,
            periodUpdatedAt: modelTimestamp,
            statusUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeTask(task, deviceId: deviceId, timestamp: fallbackTimestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["title_updated_at"] as? String == expectedTs)
        #expect(json["date_updated_at"] as? String == expectedTs)
        #expect(json["period_updated_at"] as? String == expectedTs)
        #expect(json["status_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a task that has no per-field LWW timestamps (all nil).
    /// Expected: Serialized JSON should fall back to the provided timestamp.
    @Test func testSerializerFallsBackForTaskWithoutMetadata() throws {
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let task = DataModel.Task(title: "Test")

        let data = SyncSerializer.serializeTask(task, deviceId: deviceId, timestamp: fallbackTimestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(fallbackTimestamp)
        #expect(json["title_updated_at"] as? String == expectedTs)
        #expect(json["date_updated_at"] as? String == expectedTs)
        #expect(json["period_updated_at"] as? String == expectedTs)
        #expect(json["status_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a note that has per-field LWW timestamps set.
    /// Expected: Serialized JSON should use the model's timestamps, not the fallback.
    @Test func testSerializerUsesNoteModelMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let note = DataModel.Note(
            title: "Test",
            titleUpdatedAt: modelTimestamp,
            contentUpdatedAt: modelTimestamp,
            dateUpdatedAt: modelTimestamp,
            periodUpdatedAt: modelTimestamp,
            statusUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeNote(note, deviceId: deviceId, timestamp: fallbackTimestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["title_updated_at"] as? String == expectedTs)
        #expect(json["content_updated_at"] as? String == expectedTs)
        #expect(json["date_updated_at"] as? String == expectedTs)
        #expect(json["period_updated_at"] as? String == expectedTs)
        #expect(json["status_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a collection that has titleUpdatedAt set.
    /// Expected: Serialized JSON should use the model's timestamp, not the fallback.
    @Test func testSerializerUsesCollectionModelMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let collection = DataModel.Collection(
            title: "Test",
            titleUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeCollection(
            collection, deviceId: deviceId, timestamp: fallbackTimestamp
        )
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["title_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a task assignment with statusUpdatedAt set.
    /// Expected: Serialized JSON should use the assignment's timestamp, not the fallback.
    @Test func testSerializerUsesTaskAssignmentMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let assignment = TaskAssignment(
            period: .day,
            date: referenceDate,
            status: .open,
            statusUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeTaskAssignment(
            assignment, taskId: UUID(), deviceId: deviceId, timestamp: fallbackTimestamp
        )
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["status_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a note assignment with statusUpdatedAt set.
    /// Expected: Serialized JSON should use the assignment's timestamp, not the fallback.
    @Test func testSerializerUsesNoteAssignmentMetadata() throws {
        let modelTimestamp = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let fallbackTimestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let assignment = NoteAssignment(
            period: .day,
            date: referenceDate,
            status: .active,
            statusUpdatedAt: modelTimestamp
        )

        let data = SyncSerializer.serializeNoteAssignment(
            assignment, noteId: UUID(), deviceId: deviceId, timestamp: fallbackTimestamp
        )
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(modelTimestamp)
        #expect(json["status_updated_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a spread with deletedAt on the model but none passed as parameter.
    /// Expected: Serialized JSON should use the model's deletedAt.
    @Test func testSerializerUsesModelDeletedAt() throws {
        let deletedDate = SyncDateFormatting.parseTimestamp("2025-06-01T00:00:00.000Z")!
        let timestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let task = DataModel.Task(
            title: "Deleted task",
            deletedAt: deletedDate
        )

        let data = SyncSerializer.serializeTask(task, deviceId: deviceId, timestamp: timestamp)
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(deletedDate)
        #expect(json["deleted_at"] as? String == expectedTs)
    }

    /// Conditions: Serialize a task with deletedAt passed as parameter (overrides model).
    /// Expected: Parameter deletedAt should take precedence over model's deletedAt.
    @Test func testSerializerParameterDeletedAtOverridesModel() throws {
        let modelDeletedAt = SyncDateFormatting.parseTimestamp("2025-01-01T00:00:00.000Z")!
        let paramDeletedAt = SyncDateFormatting.parseTimestamp("2025-06-01T00:00:00.000Z")!
        let timestamp = SyncDateFormatting.parseTimestamp("2025-12-31T23:59:59.000Z")!

        let task = DataModel.Task(
            title: "Deleted task",
            deletedAt: modelDeletedAt
        )

        let data = SyncSerializer.serializeTask(
            task, deviceId: deviceId, timestamp: timestamp, deletedAt: paramDeletedAt
        )
        let json = try JSONSerialization.jsonObject(with: data!) as! [String: Any]

        let expectedTs = SyncDateFormatting.formatTimestamp(paramDeletedAt)
        #expect(json["deleted_at"] as? String == expectedTs)
    }
}
