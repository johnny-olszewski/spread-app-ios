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

    /// Conditions: Valid task record data.
    /// Expected: Should return merge_task RPC name and MergeTaskParams.
    @Test func testBuildMergeParamsForTask() {
        let record = makeTaskRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .task, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_task")
        #expect(result?.params is MergeTaskParams)
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

    /// Conditions: Valid task assignment record data.
    /// Expected: Should return merge_task_assignment RPC name.
    @Test func testBuildMergeParamsForTaskAssignment() {
        let record = makeTaskAssignmentRecord()
        let userId = UUID()

        let result = SyncSerializer.buildMergeParams(
            entityType: .taskAssignment, recordData: record, userId: userId
        )

        #expect(result != nil)
        #expect(result?.rpcName == "merge_task_assignment")
        #expect(result?.params is MergeTaskAssignmentParams)
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

    // MARK: - Nil Encoding

    /// Conditions: MergeSpreadParams with nil optional fields.
    /// Expected: Encoded JSON should contain null values for p_start_date, p_end_date, p_deleted_at.
    @Test func testMergeSpreadParamsEncodesNilAsNull() throws {
        let params = MergeSpreadParams(
            pId: UUID().uuidString, pUserId: UUID().uuidString,
            pDeviceId: UUID().uuidString, pPeriod: "day", pDate: "2025-03-15",
            pStartDate: nil, pEndDate: nil,
            pCreatedAt: "2025-03-15T10:00:00.000Z", pDeletedAt: nil,
            pPeriodUpdatedAt: "2025-03-15T10:00:00.000Z",
            pDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pStartDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pEndDateUpdatedAt: "2025-03-15T10:00:00.000Z"
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

    /// Conditions: MergeTaskParams with nil deleted_at.
    /// Expected: Encoded JSON should contain null value for p_deleted_at.
    @Test func testMergeTaskParamsEncodesNilDeletedAtAsNull() throws {
        let params = MergeTaskParams(
            pId: UUID().uuidString, pUserId: UUID().uuidString,
            pDeviceId: UUID().uuidString, pTitle: "Test", pDate: "2025-03-15",
            pPeriod: "day", pStatus: "open",
            pCreatedAt: "2025-03-15T10:00:00.000Z", pDeletedAt: nil,
            pTitleUpdatedAt: "2025-03-15T10:00:00.000Z",
            pDateUpdatedAt: "2025-03-15T10:00:00.000Z",
            pPeriodUpdatedAt: "2025-03-15T10:00:00.000Z",
            pStatusUpdatedAt: "2025-03-15T10:00:00.000Z"
        )

        let data = try JSONEncoder().encode(params)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json.keys.contains("p_deleted_at"))
        #expect(json["p_deleted_at"] is NSNull)
    }

    // MARK: - Pull: createTask

    /// Conditions: Valid server task row.
    /// Expected: Should create a task with matching properties.
    @Test func testCreateTaskFromValidRow() {
        let id = UUID()
        let row = ServerTaskRow(
            id: id, title: "Test task", date: "2025-03-15",
            period: "day", status: "open",
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let task = SyncSerializer.createTask(from: row)

        #expect(task != nil)
        #expect(task?.id == id)
        #expect(task?.title == "Test task")
        #expect(task?.period == .day)
        #expect(task?.status == .open)
    }

    /// Conditions: Server task row with deletedAt set.
    /// Expected: Should return nil (soft-deleted).
    @Test func testCreateTaskReturnsNilForDeletedRow() {
        let row = ServerTaskRow(
            id: UUID(), title: "Deleted", date: "2025-03-15",
            period: "day", status: "open",
            createdAt: "2025-03-15T10:00:00.000Z",
            deletedAt: "2025-03-16T10:00:00.000Z", revision: 2
        )

        #expect(SyncSerializer.createTask(from: row) == nil)
    }

    /// Conditions: Server task row with invalid period.
    /// Expected: Should return nil.
    @Test func testCreateTaskReturnsNilForInvalidPeriod() {
        let row = ServerTaskRow(
            id: UUID(), title: "Bad", date: "2025-03-15",
            period: "weekly", status: "open",
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        #expect(SyncSerializer.createTask(from: row) == nil)
    }

    // MARK: - Pull: createNote

    /// Conditions: Valid server note row.
    /// Expected: Should create a note with matching properties.
    @Test func testCreateNoteFromValidRow() {
        let id = UUID()
        let row = ServerNoteRow(
            id: id, title: "Note title", content: "Note body",
            date: "2025-06-01", period: "month", status: "active",
            createdAt: "2025-06-01T08:00:00.000Z", deletedAt: nil, revision: 5
        )

        let note = SyncSerializer.createNote(from: row)

        #expect(note != nil)
        #expect(note?.id == id)
        #expect(note?.title == "Note title")
        #expect(note?.content == "Note body")
        #expect(note?.period == .month)
    }

    // MARK: - Pull: createCollection

    /// Conditions: Valid server collection row.
    /// Expected: Should create a collection with matching properties.
    @Test func testCreateCollectionFromValidRow() {
        let id = UUID()
        let row = ServerCollectionRow(
            id: id, title: "My Collection",
            createdAt: "2025-01-01T00:00:00.000Z", deletedAt: nil, revision: 1
        )

        let collection = SyncSerializer.createCollection(from: row)

        #expect(collection != nil)
        #expect(collection?.id == id)
        #expect(collection?.title == "My Collection")
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

    // MARK: - Pull: createTaskAssignment

    /// Conditions: Valid server task assignment row.
    /// Expected: Should create a TaskAssignment with correct period, date, status.
    @Test func testCreateTaskAssignmentFromValidRow() {
        let row = ServerTaskAssignmentRow(
            id: UUID(), taskId: UUID(), period: "day",
            date: "2025-03-15", status: "open",
            createdAt: "2025-03-15T10:00:00.000Z", deletedAt: nil, revision: 1
        )

        let assignment = SyncSerializer.createTaskAssignment(from: row)

        #expect(assignment != nil)
        #expect(assignment?.period == .day)
        #expect(assignment?.status == .open)
    }

    /// Conditions: Server task assignment row with deletedAt set.
    /// Expected: Should return nil.
    @Test func testCreateTaskAssignmentReturnsNilForDeletedRow() {
        let row = ServerTaskAssignmentRow(
            id: UUID(), taskId: UUID(), period: "day",
            date: "2025-03-15", status: "open",
            createdAt: "2025-03-15T10:00:00.000Z",
            deletedAt: "2025-03-16T10:00:00.000Z", revision: 2
        )

        #expect(SyncSerializer.createTaskAssignment(from: row) == nil)
    }

    // MARK: - Pull: createNoteAssignment

    /// Conditions: Valid server note assignment row.
    /// Expected: Should create a NoteAssignment with correct properties.
    @Test func testCreateNoteAssignmentFromValidRow() {
        let row = ServerNoteAssignmentRow(
            id: UUID(), noteId: UUID(), period: "month",
            date: "2025-06-01", status: "active",
            createdAt: "2025-06-01T08:00:00.000Z", deletedAt: nil, revision: 3
        )

        let assignment = SyncSerializer.createNoteAssignment(from: row)

        #expect(assignment != nil)
        #expect(assignment?.period == .month)
    }

    // MARK: - Apply Rows

    /// Conditions: A server task row applied to an existing task.
    /// Expected: Task properties should be updated.
    @Test @MainActor func testApplyTaskRowUpdatesProperties() {
        let task = DataModel.Task(
            id: UUID(), title: "Old title", createdDate: .now,
            date: .now, period: .day, status: .open
        )
        let row = ServerTaskRow(
            id: task.id, title: "New title", date: "2025-06-01",
            period: "month", status: "complete",
            createdAt: "2025-01-01T00:00:00.000Z", deletedAt: nil, revision: 5
        )

        let applied = SyncSerializer.applyTaskRow(row, to: task)

        #expect(applied)
        #expect(task.title == "New title")
        #expect(task.period == .month)
        #expect(task.status == .complete)
    }

    /// Conditions: A deleted server task row applied to an existing task.
    /// Expected: Should return false (caller handles deletion).
    @Test @MainActor func testApplyDeletedTaskRowReturnsFalse() {
        let task = DataModel.Task(
            id: UUID(), title: "Test", createdDate: .now,
            date: .now, period: .day, status: .open
        )
        let row = ServerTaskRow(
            id: task.id, title: "Test", date: "2025-03-15",
            period: "day", status: "open",
            createdAt: "2025-01-01T00:00:00.000Z",
            deletedAt: "2025-03-16T00:00:00.000Z", revision: 2
        )

        #expect(!SyncSerializer.applyTaskRow(row, to: task))
    }

    /// Conditions: A server collection row applied to an existing collection.
    /// Expected: Collection title should be updated.
    @Test @MainActor func testApplyCollectionRowUpdatesTitle() {
        let collection = DataModel.Collection(
            id: UUID(), title: "Old", createdDate: .now
        )
        let row = ServerCollectionRow(
            id: collection.id, title: "Updated",
            createdAt: "2025-01-01T00:00:00.000Z", deletedAt: nil, revision: 3
        )

        let applied = SyncSerializer.applyCollectionRow(row, to: collection)

        #expect(applied)
        #expect(collection.title == "Updated")
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
            "period_updated_at": ts,
            "date_updated_at": ts,
            "start_date_updated_at": ts,
            "end_date_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeTaskRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "title": "Test",
            "date": "2025-03-15",
            "period": "day",
            "status": "open",
            "created_at": ts,
            "deleted_at": NSNull(),
            "title_updated_at": ts,
            "date_updated_at": ts,
            "period_updated_at": ts,
            "status_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeCollectionRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "title": "Test Collection",
            "created_at": ts,
            "deleted_at": NSNull(),
            "title_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }

    private func makeTaskAssignmentRecord() -> Data {
        let ts = SyncDateFormatting.formatTimestamp(.now)
        let record: [String: Any] = [
            "id": UUID().uuidString,
            "device_id": UUID().uuidString,
            "task_id": UUID().uuidString,
            "period": "day",
            "date": "2025-03-15",
            "status": "open",
            "created_at": ts,
            "deleted_at": NSNull(),
            "status_updated_at": ts
        ]
        return try! JSONSerialization.data(withJSONObject: record)
    }
}
