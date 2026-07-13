import Foundation
import Testing
@testable import Spread

struct SyncSerializerTests {

    // MARK: - Date Formatting

    /// Conditions: A known date.
    /// Expected: formatDate should produce yyyy-MM-dd string.
    @Test func testFormatDateProducesCorrectString() {
        let date = SyncDateFormatting.parseDate("2025-03-15")!
        #expect(SyncDateFormatting.formatDate(date) == "2025-03-15")
    }

    /// Conditions: A valid timestamp string.
    /// Expected: parseTimestamp and formatTimestamp should round-trip.
    @Test func testTimestampRoundTrips() {
        let original = "2025-03-15T10:30:00.000Z"
        let date = SyncDateFormatting.parseTimestamp(original)
        #expect(date != nil)
        let formatted = SyncDateFormatting.formatTimestamp(date!)
        #expect(formatted == original)
    }

    /// Conditions: An invalid date string.
    /// Expected: parseDate should return nil.
    @Test func testParseDateReturnsNilForInvalidInput() {
        #expect(SyncDateFormatting.parseDate("not-a-date") == nil)
    }

    /// Conditions: An invalid timestamp string.
    /// Expected: parseTimestamp should return nil.
    @Test func testParseTimestampReturnsNilForInvalidInput() {
        #expect(SyncDateFormatting.parseTimestamp("not-a-timestamp") == nil)
    }

    // MARK: - buildMergeParams: Spread

    /// Conditions: Valid spread record data.
    /// Expected: Should return merge_spread RPC name and MergeSpreadParams.
    @Test func testBuildMergeParamsForSpread() {
        let record = makeSpreadRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .spread, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_spread")
        #expect(result?.params is MergeSpreadParams)
    }

    /// Conditions: Valid task entry record data.
    /// Expected: Should return merge_entry RPC name and MergeEntryParams.
    @Test func testBuildMergeParamsForTaskEntry() {
        let record = makeTaskEntryRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .entry, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_entry")
        #expect(result?.params is MergeEntryParams)
    }

    /// Conditions: A task whose `scheduledTime` is nil and whose `scheduledTimeUpdatedAt`
    /// is also nil (never explicitly stamped), serialized at a `timestamp` well after
    /// the task's `createdDate`.
    /// Expected: The emitted `scheduled_time_updated_at` falls back to `createdDate`, not
    /// `timestamp` — so a push carrying a stale/never-set nil time reports an old LWW
    /// clock and cannot outrace (and clobber) a real scheduled time set later on another
    /// device. Regression test for SPRD-312.
    @Test func testSerializeTaskEntryScheduledTimeUpdatedAtFallsBackToCreatedDateNotNow() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let pushTimestamp = created.addingTimeInterval(86_400) // one day later
        let task = DataModel.Task(
            title: "Untimed task",
            scheduledTime: nil,
            createdDate: created,
            date: created,
            period: .day,
            scheduledTimeUpdatedAt: nil
        )

        let data = SyncSerializer.serializeTaskEntry(task, deviceId: UUID(), timestamp: pushTimestamp)
        let json = try! JSONSerialization.jsonObject(with: data!) as! [String: Any]

        #expect(json["scheduled_time"] is NSNull)
        #expect(json["scheduled_time_updated_at"] as? String == SyncDateFormatting.formatTimestamp(created))
        // Contrast: a field without the SPRD-312 fix (title_updated_at) does fall back to `timestamp`.
        #expect(json["title_updated_at"] as? String == SyncDateFormatting.formatTimestamp(pushTimestamp))
    }

    /// Conditions: Valid collection record data.
    /// Expected: Should return merge_collection RPC name and MergeCollectionParams.
    @Test func testBuildMergeParamsForCollection() {
        let record = makeCollectionRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .collection, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_collection")
        #expect(result?.params is MergeCollectionParams)
    }

    /// Conditions: Valid assignment record data for a task entry.
    /// Expected: Should return merge_assignment RPC name.
    @Test func testBuildMergeParamsForAssignment() {
        let record = makeAssignmentRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .assignment, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_assignment")
        #expect(result?.params is MergeAssignmentParams)
    }

    @Test func testBuildMergeParamsForMultidayAssignmentPreservesSpreadID() throws {
        let spreadID = UUID()
        let record = makeAssignmentRecord(spreadID: spreadID)

        let result = SyncSerializer.buildMergeParams(
            entityType: .assignment,
            recordData: record,
            userId: UUID()
        )

        let params = try #require(result?.params as? MergeAssignmentParams)
        #expect(params.pSpreadId == spreadID.uuidString)
    }

    /// Conditions: Invalid JSON data.
    /// Expected: Should return nil.
    @Test func testBuildMergeParamsReturnsNilForInvalidData() {
        let badData = Data("not json".utf8)
        let result = SyncSerializer.buildMergeParams(
            entityType: .spread, recordData: badData, userId: UUID()
        )
        #expect(result == nil)
    }

    /// Conditions: Spread record missing required fields.
    /// Expected: Should return nil.
    @Test func testBuildMergeParamsReturnsNilForIncompleteSpread() {
        let incomplete: [String: Any] = ["id": UUID().uuidString]
        let data = try! JSONSerialization.data(withJSONObject: incomplete)
        let result = SyncSerializer.buildMergeParams(
            entityType: .spread, recordData: data, userId: UUID()
        )
        #expect(result == nil)
    }

    // MARK: - buildBatchMergeParams

    /// Conditions: Three valid spread mutations of the same entity type.
    /// Expected: Should return merge_spread_batch RPC name and a payload with 3 rows, no failures.
    @Test func testBuildBatchMergeParamsWrapsAllRows() {
        let mutations = (0..<3).map { _ in (mutationID: UUID(), recordData: makeSpreadRecord()) }

        let result = SyncSerializer.buildBatchMergeParams(
            entityType: .spread, mutations: mutations, userId: UUID()
        )

        #expect(result.rpcName == "merge_spread_batch")
        #expect(result.params.rows.count == 3)
        #expect(result.failedMutationIDs.isEmpty)
    }

    /// Conditions: One valid spread mutation and one with invalid record data.
    /// Expected: Valid row is included in the payload; invalid mutation's id is reported as failed.
    @Test func testBuildBatchMergeParamsFiltersInvalidRows() {
        let validID = UUID()
        let invalidID = UUID()
        let mutations = [
            (mutationID: validID, recordData: makeSpreadRecord()),
            (mutationID: invalidID, recordData: Data("not json".utf8))
        ]

        let result = SyncSerializer.buildBatchMergeParams(
            entityType: .spread, mutations: mutations, userId: UUID()
        )

        #expect(result.params.rows.count == 1)
        #expect(result.failedMutationIDs == [invalidID])
    }

    /// Conditions: Empty mutation list.
    /// Expected: Should return an empty rows payload with no failures.
    @Test func testBuildBatchMergeParamsHandlesEmptyInput() {
        let result = SyncSerializer.buildBatchMergeParams(
            entityType: .spread, mutations: [], userId: UUID()
        )

        #expect(result.params.rows.isEmpty)
        #expect(result.failedMutationIDs.isEmpty)
    }

    // MARK: - Nil Encoding

    /// Conditions: MergeSpreadParams with nil optional fields.
    /// Expected: Encoded JSON should contain null values for p_start_date, p_end_date, p_deleted_at.
    @Test func testMergeSpreadParamsEncodesNilAsNull() throws {
        let params = MergeSpreadParams(
            pId: UUID().uuidString, pUserId: UUID().uuidString,
            pDeviceId: UUID().uuidString, pPeriod: "day", pDate: "2025-03-15",
            pStartDate: nil, pEndDate: nil,
            pIsFavorite: false, pCustomName: nil, pUsesDynamicName: true,
            pCreatedAt: "2025-03-15T10:00:00.000Z", pDeletedAt: nil,
            pPeriodUpdatedAt: "2025-03-15T10:00:00.000Z",
            pDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pStartDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pEndDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pIsFavoriteUpdatedAt: "2025-03-15T10:00:00.000Z",
            pCustomNameUpdatedAt: "2025-03-15T10:00:00.000Z",
            pUsesDynamicNameUpdatedAt: "2025-03-15T10:00:00.000Z"
        )

        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // All keys must be present (PostgreSQL requires them for function signature matching)
        #expect(json.keys.contains("p_start_date"))
        #expect(json.keys.contains("p_end_date"))
        #expect(json.keys.contains("p_deleted_at"))

        // Values should be NSNull (JSON null)
        #expect(json["p_start_date"] is NSNull)
        #expect(json["p_end_date"] is NSNull)
        #expect(json["p_deleted_at"] is NSNull)
    }

    /// Conditions: MergeEntryParams for a task with nil deleted_at, content, and period.
    /// Expected: Encoded JSON should contain null values for those fields.
    @Test func testMergeEntryParamsEncodesNilAsNull() throws {
        let params = MergeEntryParams(
            pId: UUID().uuidString, pUserId: UUID().uuidString,
            pDeviceId: UUID().uuidString, pType: "task", pTitle: "Test",
            pContent: nil, pDate: "2025-03-15", pPeriod: "day", pStatus: "open",
            pBody: nil, pPriority: "none", pDueDate: nil, pScheduledTime: nil, pListId: nil,
            pCreatedAt: "2025-03-15T10:00:00.000Z", pDeletedAt: nil,
            pTitleUpdatedAt: "2025-03-15T10:00:00.000Z",
            pContentUpdatedAt: "2025-03-15T10:00:00.000Z",
            pDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pPeriodUpdatedAt: "2025-03-15T10:00:00.000Z",
            pStatusUpdatedAt: "2025-03-15T10:00:00.000Z",
            pBodyUpdatedAt: "2025-03-15T10:00:00.000Z",
            pPriorityUpdatedAt: "2025-03-15T10:00:00.000Z",
            pDueDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pScheduledTimeUpdatedAt: "2025-03-15T10:00:00.000Z",
            pListUpdatedAt: "2025-03-15T10:00:00.000Z"
        )

        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json.keys.contains("p_deleted_at"))
        #expect(json["p_deleted_at"] is NSNull)
        #expect(json["p_content"] is NSNull)
        #expect(json["p_body"] is NSNull)
        #expect(json["p_due_date"] is NSNull)
        #expect(json["p_list_id"] is NSNull)
    }

    // MARK: - Pull: createTask

    /// Conditions: Valid server entry row of type task.
    /// Expected: Should create a task with matching properties.
    @Test func testCreateTaskFromValidRow() {
        let id = UUID()
        let row = ServerEntryRow(
            id: id, type: "task", title: "Test task", content: nil,
            date: "2025-03-15", period: "day", status: "open",
            body: "Details", priority: "medium", dueDate: "2025-03-20", scheduledTime: nil, listId: nil,
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let task = SyncSerializer.createTask(from: row)

        #expect(task != nil)
        #expect(task?.id == id)
        #expect(task?.title == "Test task")
        #expect(task?.body == "Details")
        #expect(task?.priority == .medium)
        #expect(task?.dueDate != nil)
        #expect(task?.date != nil)
        #expect(task?.period == .day)
        #expect(task?.status == .open)
    }

    /// Conditions: Server entry row has nil preferred date and period.
    /// Expected: Created task should preserve nil date/period directly (no local fallback values).
    @Test func testCreateTaskFromNilPreferredAssignmentRow() {
        let row = ServerEntryRow(
            id: UUID(), type: "task", title: "Inbox task", content: nil,
            date: nil, period: nil, status: "open",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let task = SyncSerializer.createTask(from: row)

        #expect(task != nil)
        #expect(task?.date == nil)
        #expect(task?.period == nil)
    }

    /// Conditions: Server entry row with deletedAt set.
    /// Expected: Should return nil (soft-deleted).
    @Test func testCreateTaskReturnsNilForDeletedRow() {
        let row = ServerEntryRow(
            id: UUID(), type: "task", title: "Deleted", content: nil,
            date: "2025-03-15", period: "day", status: "open",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-03-15T10:00:00.000Z",
            deletedAt: "2025-03-16T10:00:00.000Z", revision: 2
        )

        #expect(SyncSerializer.createTask(from: row) == nil)
    }

    /// Conditions: Server entry row with invalid period.
    /// Expected: Should return nil.
    @Test func testCreateTaskReturnsNilForInvalidPeriod() {
        let row = ServerEntryRow(
            id: UUID(), type: "task", title: "Bad", content: nil,
            date: "2025-03-15", period: "weekly", status: "open",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        #expect(SyncSerializer.createTask(from: row) == nil)
    }

    // MARK: - Pull: createNote

    /// Conditions: Valid server entry row of type note.
    /// Expected: Should create a note with matching properties.
    @Test func testCreateNoteFromValidRow() {
        let id = UUID()
        let row = ServerEntryRow(
            id: id, type: "note", title: "Note title", content: "Note body",
            date: "2025-06-01", period: "month", status: "active",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-06-01T08:00:00.000Z", deletedAt: nil, revision: 5
        )

        let note = SyncSerializer.createNote(from: row)

        #expect(note != nil)
        #expect(note?.id == id)
        #expect(note?.title == "Note title")
        #expect(note?.content == "Note body")
        #expect(note?.period == .month)
    }

    /// Conditions: Server entry row of type note with nil preferred date.
    /// Expected: Created note should have a nil date.
    @Test func testCreateNoteFromNilDateRow() {
        let row = ServerEntryRow(
            id: UUID(), type: "note", title: "Dateless note", content: "Body",
            date: nil, period: "day", status: "active",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-06-01T08:00:00.000Z", deletedAt: nil, revision: 5
        )

        let note = SyncSerializer.createNote(from: row)

        #expect(note != nil)
        #expect(note?.date == nil)
    }

    // MARK: - Pull: createCollection

    /// Conditions: Valid server collection row.
    /// Expected: Should create a collection with matching properties.
    @Test func testCreateCollectionFromValidRow() {
        let id = UUID()
        let row = ServerCollectionRow(
            id: id, title: "My Collection", content: "Some text",
            createdAt: "2025-01-01T00:00:00.000Z",
            modifiedAt: "2025-01-02T00:00:00.000Z",
            deletedAt: nil, revision: 1
        )

        let collection = SyncSerializer.createCollection(from: row)

        #expect(collection != nil)
        #expect(collection?.id == id)
        #expect(collection?.title == "My Collection")
        #expect(collection?.content == "Some text")
    }

    // MARK: - Pull: createSpread

    /// Conditions: Valid server spread row with day period.
    /// Expected: Should create a spread with correct period and date.
    @Test func testCreateSpreadFromDayRow() {
        let id = UUID()
        let row = ServerSpreadRow(
            id: id, period: "day", date: "2025-03-15",
            startDate: nil, endDate: nil,
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let spread = SyncSerializer.createSpread(from: row, calendar: .current)

        #expect(spread != nil)
        #expect(spread?.id == id)
        #expect(spread?.period == .day)
    }

    /// Conditions: Valid server spread row with multiday period.
    /// Expected: Should create a spread with start and end dates.
    @Test func testCreateSpreadFromMultidayRow() {
        let row = ServerSpreadRow(
            id: UUID(), period: "multiday", date: "2025-03-15",
            startDate: "2025-03-15", endDate: "2025-03-20",
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let spread = SyncSerializer.createSpread(from: row, calendar: .current)
        #expect(spread != nil)
        #expect(spread?.period == .multiday)
    }

    /// Conditions: Multiday spread row missing start/end dates.
    /// Expected: Should return nil.
    @Test func testCreateSpreadReturnsNilForMultidayWithoutDates() {
        let row = ServerSpreadRow(
            id: UUID(), period: "multiday", date: "2025-03-15",
            startDate: nil, endDate: nil,
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        #expect(SyncSerializer.createSpread(from: row, calendar: .current) == nil)
    }

    // MARK: - Pull: createAssignment

    /// Conditions: Valid server assignment row for a task entry.
    /// Expected: Should create an Assignment with correct period, date, status.
    @Test func testCreateAssignmentFromValidTaskRow() {
        let rowID = UUID()
        let row = ServerAssignmentRow(
            id: rowID, entryId: UUID(), entryType: "task", period: "day",
            date: "2025-03-15", spreadId: nil, status: "open",
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let assignment = SyncSerializer.createAssignment(from: row)

        #expect(assignment != nil)
        #expect(assignment?.id == rowID)
        #expect(assignment?.period == .day)
        #expect(assignment?.status == .open)
    }

    @Test func testCreateAssignmentFromMultidayRowPreservesSpreadIdentity() {
        let spreadID = UUID()
        let row = ServerAssignmentRow(
            id: UUID(),
            entryId: UUID(),
            entryType: "task",
            period: "multiday",
            date: "2025-03-15",
            spreadId: spreadID,
            status: "open",
            createdAt: "2025-03-15T10:00:00.000Z",
            deletedAt: nil,
            revision: 1
        )

        let assignment = SyncSerializer.createAssignment(from: row)

        #expect(assignment?.spreadID == spreadID)
    }

    /// Conditions: Server assignment row with deletedAt set.
    /// Expected: Should return nil.
    @Test func testCreateAssignmentReturnsNilForDeletedRow() {
        let row = ServerAssignmentRow(
            id: UUID(), entryId: UUID(), entryType: "task", period: "day",
            date: "2025-03-15", spreadId: nil, status: "open",
            createdAt: "2025-03-15T10:00:00.000Z",
            deletedAt: "2025-03-16T10:00:00.000Z", revision: 2
        )

        #expect(SyncSerializer.createAssignment(from: row) == nil)
    }

    /// Conditions: Valid server assignment row for a note entry.
    /// Expected: Should create an Assignment with correct properties.
    @Test func testCreateAssignmentFromValidNoteRow() {
        let rowID = UUID()
        let row = ServerAssignmentRow(
            id: rowID, entryId: UUID(), entryType: "note", period: "month",
            date: "2025-06-01", spreadId: nil, status: "active",
            createdAt: "2025-06-01T08:00:00.000Z", deletedAt: nil, revision: 3
        )

        let assignment = SyncSerializer.createAssignment(from: row)

        #expect(assignment != nil)
        #expect(assignment?.id == rowID)
        #expect(assignment?.period == .month)
    }

    // MARK: - Apply Rows

    /// Conditions: A server entry row applied to an existing task.
    /// Expected: Task properties should be updated.
    @Test @MainActor func testApplyTaskRowUpdatesProperties() {
        let task = DataModel.Task(
            id: UUID(), title: "Old title", createdDate: .now,
            date: .now, period: .day, status: .open
        )
        let row = ServerEntryRow(
            id: task.id, type: "task", title: "New title", content: nil,
            date: "2025-06-01", period: "month", status: "complete",
            body: "New body", priority: "high", dueDate: "2025-06-10", scheduledTime: nil, listId: nil,
            createdAt: "2025-01-01T00:00:00.000Z", deletedAt: nil, revision: 5
        )

        let applied = SyncSerializer.applyTaskRow(row, to: task)

        #expect(applied)
        #expect(task.title == "New title")
        #expect(task.body == "New body")
        #expect(task.priority == .high)
        #expect(task.dueDate != nil)
        #expect(task.date != nil)
        #expect(task.period == .month)
        #expect(task.status == .complete)
    }

    /// Conditions: A deleted server entry row applied to an existing task.
    /// Expected: Should return false (caller handles deletion).
    @Test @MainActor func testApplyDeletedTaskRowReturnsFalse() {
        let task = DataModel.Task(
            id: UUID(), title: "Test", createdDate: .now,
            date: .now, period: .day, status: .open
        )
        let row = ServerEntryRow(
            id: task.id, type: "task", title: "Test", content: nil,
            date: "2025-03-15", period: "day", status: "open",
            body: nil, priority: nil, dueDate: nil, scheduledTime: nil, listId: nil,
            createdAt: "2025-01-01T00:00:00.000Z",
            deletedAt: "2025-03-16T00:00:00.000Z", revision: 2
        )

        #expect(!SyncSerializer.applyTaskRow(row, to: task))
    }

    /// Conditions: A server collection row applied to an existing collection.
    /// Expected: Collection title and content should be updated.
    @Test @MainActor func testApplyCollectionRowUpdatesTitle() {
        let collection = DataModel.Collection(
            id: UUID(), title: "Old", content: "old content", createdDate: .now
        )
        let row = ServerCollectionRow(
            id: collection.id, title: "Updated", content: "new content",
            createdAt: "2025-01-01T00:00:00.000Z",
            modifiedAt: "2025-01-02T00:00:00.000Z",
            deletedAt: nil, revision: 3
        )

        let applied = SyncSerializer.applyCollectionRow(row, to: collection)

        #expect(applied)
        #expect(collection.title == "Updated")
        #expect(collection.content == "new content")
    }

    // MARK: - Helpers

    private func makeSpreadRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "period": "day",
            "date": "2025-03-15",
            "created_at": ts,
            "deleted_at": NSNull(),
            "is_favorite": false,
            "custom_name": NSNull(),
            "uses_dynamic_name": true,
            "period_updated_at": ts,
            "date_updated_at": ts,
            "start_date_updated_at": ts,
            "end_date_updated_at": ts,
            "is_favorite_updated_at": ts,
            "custom_name_updated_at": ts,
            "uses_dynamic_name_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeTaskEntryRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "type": "task",
            "title": "Test",
            "content": NSNull(),
            "body": NSNull(),
            "priority": "none",
            "due_date": NSNull(),
            "scheduled_time": NSNull(),
            "list_id": NSNull(),
            "date": "2025-03-15",
            "period": "day",
            "status": "open",
            "created_at": ts,
            "deleted_at": NSNull(),
            "title_updated_at": ts,
            "content_updated_at": ts,
            "date_updated_at": ts,
            "period_updated_at": ts,
            "status_updated_at": ts,
            "body_updated_at": ts,
            "priority_updated_at": ts,
            "due_date_updated_at": ts,
            "scheduled_time_updated_at": ts,
            "list_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeCollectionRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "title": "Test Collection",
            "content": "Some content",
            "created_at": ts,
            "modified_at": ts,
            "deleted_at": NSNull(),
            "title_updated_at": ts,
            "content_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeAssignmentRecord(spreadID: UUID? = nil) -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "entry_id": UUID().uuidString,
            "entry_type": "task",
            "period": "day",
            "date": "2025-03-15",
            "spread_id": spreadID?.uuidString ?? NSNull(),
            "status": "open",
            "created_at": ts,
            "deleted_at": NSNull(),
            "status_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }
}
