import Foundation

// MARK: - Date Formatting

/// Shared date formatters for sync serialization.
enum SyncDateFormatting {
    /// ISO 8601 formatter for timestamp fields.
    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Date-only formatter for date fields (yyyy-MM-dd).
    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func formatTimestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    static func formatDate(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    static func parseTimestamp(_ string: String) -> Date? {
        timestampFormatter.date(from: string)
    }

    static func parseDate(_ string: String) -> Date? {
        dateOnlyFormatter.date(from: string)
    }
}

// MARK: - Merge RPC Parameter Types

/// Parameters for the `merge_spread` RPC.
struct MergeSpreadParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pPeriod: String
    let pDate: String
    let pStartDate: String?
    let pEndDate: String?
    let pCreatedAt: String
    let pDeletedAt: String?
    let pPeriodUpdatedAt: String
    let pDateUpdatedAt: String
    let pStartDateUpdatedAt: String
    let pEndDateUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pPeriod = "p_period"
        case pDate = "p_date"
        case pStartDate = "p_start_date"
        case pEndDate = "p_end_date"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pStartDateUpdatedAt = "p_start_date_updated_at"
        case pEndDateUpdatedAt = "p_end_date_updated_at"
    }
}

/// Parameters for the `merge_task` RPC.
struct MergeTaskParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTitle: String
    let pDate: String
    let pPeriod: String
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String
    let pDateUpdatedAt: String
    let pPeriodUpdatedAt: String
    let pStatusUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTitle = "p_title"
        case pDate = "p_date"
        case pPeriod = "p_period"
        case pStatus = "p_status"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pStatusUpdatedAt = "p_status_updated_at"
    }
}

/// Parameters for the `merge_note` RPC.
struct MergeNoteParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTitle: String
    let pContent: String
    let pDate: String
    let pPeriod: String
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String
    let pContentUpdatedAt: String
    let pDateUpdatedAt: String
    let pPeriodUpdatedAt: String
    let pStatusUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTitle = "p_title"
        case pContent = "p_content"
        case pDate = "p_date"
        case pPeriod = "p_period"
        case pStatus = "p_status"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
        case pContentUpdatedAt = "p_content_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pStatusUpdatedAt = "p_status_updated_at"
    }
}

/// Parameters for the `merge_collection` RPC.
struct MergeCollectionParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTitle: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTitle = "p_title"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
    }
}

/// Parameters for the `merge_task_assignment` RPC.
struct MergeTaskAssignmentParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTaskId: String
    let pPeriod: String
    let pDate: String
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pStatusUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTaskId = "p_task_id"
        case pPeriod = "p_period"
        case pDate = "p_date"
        case pStatus = "p_status"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pStatusUpdatedAt = "p_status_updated_at"
    }
}

/// Parameters for the `merge_note_assignment` RPC.
struct MergeNoteAssignmentParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pNoteId: String
    let pPeriod: String
    let pDate: String
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pStatusUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pNoteId = "p_note_id"
        case pPeriod = "p_period"
        case pDate = "p_date"
        case pStatus = "p_status"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pStatusUpdatedAt = "p_status_updated_at"
    }
}

// MARK: - Server Row Types (Pull)

/// A row from the `spreads` table.
struct ServerSpreadRow: Decodable, Sendable {
    let id: UUID
    let period: String
    let date: String
    let startDate: String?
    let endDate: String?
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, period, date, revision
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `tasks` table.
struct ServerTaskRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let date: String
    let period: String
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, date, period, status, revision
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `notes` table.
struct ServerNoteRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let content: String
    let date: String
    let period: String
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, content, date, period, status, revision
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `collections` table.
struct ServerCollectionRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, revision
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `task_assignments` table.
struct ServerTaskAssignmentRow: Decodable, Sendable {
    let id: UUID
    let taskId: UUID
    let period: String
    let date: String
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, period, date, status, revision
        case taskId = "task_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `note_assignments` table.
struct ServerNoteAssignmentRow: Decodable, Sendable {
    let id: UUID
    let noteId: UUID
    let period: String
    let date: String
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, period, date, status, revision
        case noteId = "note_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

// MARK: - Serializer

/// Converts between local SwiftData models and server sync formats.
///
/// Handles serialization for push (local → merge RPC params) and
/// deserialization for pull (server rows → local model updates).
enum SyncSerializer {

    // MARK: - Push Serialization (Local → Record Data)

    /// Serializes a spread into JSON record data for the outbox.
    static func serializeSpread(
        _ spread: DataModel.Spread,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": spread.id.uuidString,
            "device_id": deviceId.uuidString,
            "period": spread.period.rawValue,
            "date": SyncDateFormatting.formatDate(spread.date),
            "start_date": spread.startDate.map { SyncDateFormatting.formatDate($0) },
            "end_date": spread.endDate.map { SyncDateFormatting.formatDate($0) },
            "created_at": SyncDateFormatting.formatTimestamp(spread.createdDate),
            "deleted_at": nil as String?,
            "period_updated_at": ts,
            "date_updated_at": ts,
            "start_date_updated_at": ts,
            "end_date_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a task into JSON record data for the outbox.
    static func serializeTask(
        _ task: DataModel.Task,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": task.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": task.title,
            "date": SyncDateFormatting.formatDate(task.date),
            "period": task.period.rawValue,
            "status": task.status.rawValue,
            "created_at": SyncDateFormatting.formatTimestamp(task.createdDate),
            "deleted_at": nil as String?,
            "title_updated_at": ts,
            "date_updated_at": ts,
            "period_updated_at": ts,
            "status_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a note into JSON record data for the outbox.
    static func serializeNote(
        _ note: DataModel.Note,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": note.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": note.title,
            "content": note.content,
            "date": SyncDateFormatting.formatDate(note.date),
            "period": note.period.rawValue,
            "status": note.status.rawValue,
            "created_at": SyncDateFormatting.formatTimestamp(note.createdDate),
            "deleted_at": nil as String?,
            "title_updated_at": ts,
            "content_updated_at": ts,
            "date_updated_at": ts,
            "period_updated_at": ts,
            "status_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a collection into JSON record data for the outbox.
    static func serializeCollection(
        _ collection: DataModel.Collection,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": collection.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": collection.title,
            "created_at": SyncDateFormatting.formatTimestamp(collection.createdDate),
            "deleted_at": nil as String?,
            "title_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a task assignment into JSON record data for the outbox.
    static func serializeTaskAssignment(
        _ assignment: TaskAssignment,
        taskId: UUID,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let assignmentId = UUID()
        let record: [String: Any?] = [
            "id": assignmentId.uuidString,
            "device_id": deviceId.uuidString,
            "task_id": taskId.uuidString,
            "period": assignment.period.rawValue,
            "date": SyncDateFormatting.formatDate(assignment.date),
            "status": assignment.status.rawValue,
            "created_at": ts,
            "deleted_at": nil as String?,
            "status_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a note assignment into JSON record data for the outbox.
    static func serializeNoteAssignment(
        _ assignment: NoteAssignment,
        noteId: UUID,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let assignmentId = UUID()
        let record: [String: Any?] = [
            "id": assignmentId.uuidString,
            "device_id": deviceId.uuidString,
            "note_id": noteId.uuidString,
            "period": assignment.period.rawValue,
            "date": SyncDateFormatting.formatDate(assignment.date),
            "status": assignment.status.rawValue,
            "created_at": ts,
            "deleted_at": nil as String?,
            "status_updated_at": ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    // MARK: - Push: Record Data → RPC Params

    /// Converts stored record data JSON into merge RPC parameters.
    ///
    /// Adds `user_id` from the current session at push time.
    static func buildMergeParams(
        entityType: SyncEntityType,
        recordData: Data,
        userId: UUID
    ) -> (rpcName: String, params: any Encodable & Sendable)? {
        guard let json = try? JSONSerialization.jsonObject(with: recordData) as? [String: Any] else {
            return nil
        }

        let uid = userId.uuidString

        switch entityType {
        case .spread:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let period = json["period"] as? String,
                  let date = json["date"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let startDateUpdatedAt = json["start_date_updated_at"] as? String,
                  let endDateUpdatedAt = json["end_date_updated_at"] as? String else {
                return nil
            }
            let params = MergeSpreadParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pPeriod: period, pDate: date,
                pStartDate: json["start_date"] as? String,
                pEndDate: json["end_date"] as? String,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pPeriodUpdatedAt: periodUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pStartDateUpdatedAt: startDateUpdatedAt,
                pEndDateUpdatedAt: endDateUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .task:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let title = json["title"] as? String,
                  let date = json["date"] as? String,
                  let period = json["period"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String else {
                return nil
            }
            let params = MergeTaskParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTitle: title, pDate: date, pPeriod: period, pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pPeriodUpdatedAt: periodUpdatedAt,
                pStatusUpdatedAt: statusUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .note:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let title = json["title"] as? String,
                  let content = json["content"] as? String,
                  let date = json["date"] as? String,
                  let period = json["period"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String,
                  let contentUpdatedAt = json["content_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String else {
                return nil
            }
            let params = MergeNoteParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTitle: title, pContent: content,
                pDate: date, pPeriod: period, pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt,
                pContentUpdatedAt: contentUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pPeriodUpdatedAt: periodUpdatedAt,
                pStatusUpdatedAt: statusUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .collection:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let title = json["title"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String else {
                return nil
            }
            let params = MergeCollectionParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTitle: title,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .taskAssignment:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let taskId = json["task_id"] as? String,
                  let period = json["period"] as? String,
                  let date = json["date"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String else {
                return nil
            }
            let params = MergeTaskAssignmentParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTaskId: taskId, pPeriod: period, pDate: date, pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pStatusUpdatedAt: statusUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .noteAssignment:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let noteId = json["note_id"] as? String,
                  let period = json["period"] as? String,
                  let date = json["date"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String else {
                return nil
            }
            let params = MergeNoteAssignmentParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pNoteId: noteId, pPeriod: period, pDate: date, pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pStatusUpdatedAt: statusUpdatedAt
            )
            return (entityType.mergeRPCName, params)
        }
    }

    // MARK: - Pull Deserialization (Server Row → Local Model)

    /// Applies a server spread row to a local spread model.
    static func applySpreadRow(_ row: ServerSpreadRow, to spread: DataModel.Spread) -> Bool {
        guard row.deletedAt == nil else { return false }
        if let period = Period(rawValue: row.period) { spread.period = period }
        if let date = SyncDateFormatting.parseDate(row.date) { spread.date = date }
        spread.startDate = row.startDate.flatMap { SyncDateFormatting.parseDate($0) }
        spread.endDate = row.endDate.flatMap { SyncDateFormatting.parseDate($0) }
        return true
    }

    /// Creates a new local spread from a server row.
    static func createSpread(from row: ServerSpreadRow, calendar: Calendar) -> DataModel.Spread? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }

        if period == .multiday {
            guard let startDate = row.startDate.flatMap({ SyncDateFormatting.parseDate($0) }),
                  let endDate = row.endDate.flatMap({ SyncDateFormatting.parseDate($0) }) else {
                return nil
            }
            return DataModel.Spread(
                id: row.id, startDate: startDate, endDate: endDate,
                calendar: calendar, createdDate: createdAt
            )
        }

        return DataModel.Spread(
            id: row.id, period: period, date: date,
            calendar: calendar, createdDate: createdAt
        )
    }

    /// Applies a server task row to a local task model.
    static func applyTaskRow(_ row: ServerTaskRow, to task: DataModel.Task) -> Bool {
        guard row.deletedAt == nil else { return false }
        task.title = row.title
        if let date = SyncDateFormatting.parseDate(row.date) { task.date = date }
        if let period = Period(rawValue: row.period) { task.period = period }
        if let status = DataModel.Task.Status(rawValue: row.status) { task.status = status }
        return true
    }

    /// Creates a new local task from a server row.
    static func createTask(from row: ServerTaskRow) -> DataModel.Task? {
        guard row.deletedAt == nil,
              let date = SyncDateFormatting.parseDate(row.date),
              let period = Period(rawValue: row.period),
              let status = DataModel.Task.Status(rawValue: row.status),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Task(
            id: row.id, title: row.title, createdDate: createdAt,
            date: date, period: period, status: status
        )
    }

    /// Applies a server note row to a local note model.
    static func applyNoteRow(_ row: ServerNoteRow, to note: DataModel.Note) -> Bool {
        guard row.deletedAt == nil else { return false }
        note.title = row.title
        note.content = row.content
        if let date = SyncDateFormatting.parseDate(row.date) { note.date = date }
        if let period = Period(rawValue: row.period) { note.period = period }
        if let status = DataModel.Note.Status(rawValue: row.status) { note.status = status }
        return true
    }

    /// Creates a new local note from a server row.
    static func createNote(from row: ServerNoteRow) -> DataModel.Note? {
        guard row.deletedAt == nil,
              let date = SyncDateFormatting.parseDate(row.date),
              let period = Period(rawValue: row.period),
              let status = DataModel.Note.Status(rawValue: row.status),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Note(
            id: row.id, title: row.title, content: row.content,
            createdDate: createdAt, date: date, period: period, status: status
        )
    }

    /// Applies a server collection row to a local collection model.
    static func applyCollectionRow(
        _ row: ServerCollectionRow,
        to collection: DataModel.Collection
    ) -> Bool {
        guard row.deletedAt == nil else { return false }
        collection.title = row.title
        return true
    }

    /// Creates a new local collection from a server row.
    static func createCollection(from row: ServerCollectionRow) -> DataModel.Collection? {
        guard row.deletedAt == nil,
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Collection(id: row.id, title: row.title, createdDate: createdAt)
    }

    /// Converts a server task assignment row to a local TaskAssignment value.
    static func createTaskAssignment(from row: ServerTaskAssignmentRow) -> TaskAssignment? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let status = DataModel.Task.Status(rawValue: row.status) else {
            return nil
        }
        return TaskAssignment(period: period, date: date, status: status)
    }

    /// Converts a server note assignment row to a local NoteAssignment value.
    static func createNoteAssignment(from row: ServerNoteAssignmentRow) -> NoteAssignment? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let status = DataModel.Note.Status(rawValue: row.status) else {
            return nil
        }
        return NoteAssignment(period: period, date: date, status: status)
    }
}
