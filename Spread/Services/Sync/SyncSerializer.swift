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
        formatter.timeZone = .autoupdatingCurrent
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

/// Parameters for the `merge_settings` RPC.
struct MergeSettingsParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pBujoMode: String
    let pFirstWeekday: Int
    let pCreatedAt: String
    let pDeletedAt: String?
    let pBujoModeUpdatedAt: String
    let pFirstWeekdayUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pBujoMode = "p_bujo_mode"
        case pFirstWeekday = "p_first_weekday"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pBujoModeUpdatedAt = "p_bujo_mode_updated_at"
        case pFirstWeekdayUpdatedAt = "p_first_weekday_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pBujoMode, forKey: .pBujoMode)
        try container.encode(pFirstWeekday, forKey: .pFirstWeekday)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pBujoModeUpdatedAt, forKey: .pBujoModeUpdatedAt)
        try container.encode(pFirstWeekdayUpdatedAt, forKey: .pFirstWeekdayUpdatedAt)
    }
}

/// Parameters for the `merge_spread` RPC.
struct MergeSpreadParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pPeriod: String
    let pDate: String
    let pStartDate: String?
    let pEndDate: String?
    let pIsFavorite: Bool
    let pCustomName: String?
    let pUsesDynamicName: Bool
    let pCreatedAt: String
    let pDeletedAt: String?
    let pPeriodUpdatedAt: String
    let pDateUpdatedAt: String
    let pStartDateUpdatedAt: String
    let pEndDateUpdatedAt: String
    let pIsFavoriteUpdatedAt: String
    let pCustomNameUpdatedAt: String
    let pUsesDynamicNameUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pPeriod = "p_period"
        case pDate = "p_date"
        case pStartDate = "p_start_date"
        case pEndDate = "p_end_date"
        case pIsFavorite = "p_is_favorite"
        case pCustomName = "p_custom_name"
        case pUsesDynamicName = "p_uses_dynamic_name"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pStartDateUpdatedAt = "p_start_date_updated_at"
        case pEndDateUpdatedAt = "p_end_date_updated_at"
        case pIsFavoriteUpdatedAt = "p_is_favorite_updated_at"
        case pCustomNameUpdatedAt = "p_custom_name_updated_at"
        case pUsesDynamicNameUpdatedAt = "p_uses_dynamic_name_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pStartDate, forKey: .pStartDate)
        try container.encode(pEndDate, forKey: .pEndDate)
        try container.encode(pIsFavorite, forKey: .pIsFavorite)
        try container.encode(pCustomName, forKey: .pCustomName)
        try container.encode(pUsesDynamicName, forKey: .pUsesDynamicName)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pPeriodUpdatedAt, forKey: .pPeriodUpdatedAt)
        try container.encode(pDateUpdatedAt, forKey: .pDateUpdatedAt)
        try container.encode(pStartDateUpdatedAt, forKey: .pStartDateUpdatedAt)
        try container.encode(pEndDateUpdatedAt, forKey: .pEndDateUpdatedAt)
        try container.encode(pIsFavoriteUpdatedAt, forKey: .pIsFavoriteUpdatedAt)
        try container.encode(pCustomNameUpdatedAt, forKey: .pCustomNameUpdatedAt)
        try container.encode(pUsesDynamicNameUpdatedAt, forKey: .pUsesDynamicNameUpdatedAt)
    }
}

/// Parameters for the `merge_task` RPC.
struct MergeTaskParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTitle: String
    let pBody: String?
    let pPriority: String
    let pDueDate: String?
    let pDate: String?
    let pPeriod: String?
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String
    let pDateUpdatedAt: String
    let pPeriodUpdatedAt: String
    let pStatusUpdatedAt: String
    let pBodyUpdatedAt: String
    let pPriorityUpdatedAt: String
    let pDueDateUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTitle = "p_title"
        case pBody = "p_body"
        case pPriority = "p_priority"
        case pDueDate = "p_due_date"
        case pDate = "p_date"
        case pPeriod = "p_period"
        case pStatus = "p_status"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pStatusUpdatedAt = "p_status_updated_at"
        case pBodyUpdatedAt = "p_body_updated_at"
        case pPriorityUpdatedAt = "p_priority_updated_at"
        case pDueDateUpdatedAt = "p_due_date_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pTitle, forKey: .pTitle)
        try container.encode(pBody, forKey: .pBody)
        try container.encode(pPriority, forKey: .pPriority)
        try container.encode(pDueDate, forKey: .pDueDate)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pTitleUpdatedAt, forKey: .pTitleUpdatedAt)
        try container.encode(pDateUpdatedAt, forKey: .pDateUpdatedAt)
        try container.encode(pPeriodUpdatedAt, forKey: .pPeriodUpdatedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
        try container.encode(pBodyUpdatedAt, forKey: .pBodyUpdatedAt)
        try container.encode(pPriorityUpdatedAt, forKey: .pPriorityUpdatedAt)
        try container.encode(pDueDateUpdatedAt, forKey: .pDueDateUpdatedAt)
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pTitle, forKey: .pTitle)
        try container.encode(pContent, forKey: .pContent)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pTitleUpdatedAt, forKey: .pTitleUpdatedAt)
        try container.encode(pContentUpdatedAt, forKey: .pContentUpdatedAt)
        try container.encode(pDateUpdatedAt, forKey: .pDateUpdatedAt)
        try container.encode(pPeriodUpdatedAt, forKey: .pPeriodUpdatedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
    }
}

/// Parameters for the `merge_collection` RPC.
struct MergeCollectionParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pTitle: String
    let pContent: String
    let pCreatedAt: String
    let pModifiedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String
    let pContentUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pTitle = "p_title"
        case pContent = "p_content"
        case pCreatedAt = "p_created_at"
        case pModifiedAt = "p_modified_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
        case pContentUpdatedAt = "p_content_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pTitle, forKey: .pTitle)
        try container.encode(pContent, forKey: .pContent)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pModifiedAt, forKey: .pModifiedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pTitleUpdatedAt, forKey: .pTitleUpdatedAt)
        try container.encode(pContentUpdatedAt, forKey: .pContentUpdatedAt)
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pTaskId, forKey: .pTaskId)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pNoteId, forKey: .pNoteId)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
    }
}

// MARK: - Server Row Types (Pull)

/// A row from the `settings` table.
struct ServerSettingsRow: Decodable, Sendable {
    let id: UUID
    let bujoMode: String
    let firstWeekday: Int
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, revision
        case bujoMode = "bujo_mode"
        case firstWeekday = "first_weekday"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `spreads` table.
struct ServerSpreadRow: Decodable, Sendable {
    let id: UUID
    let period: String
    let date: String
    let startDate: String?
    let endDate: String?
    let isFavorite: Bool
    let customName: String?
    let usesDynamicName: Bool
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, period, date, revision
        case startDate = "start_date"
        case endDate = "end_date"
        case isFavorite = "is_favorite"
        case customName = "custom_name"
        case usesDynamicName = "uses_dynamic_name"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }

    init(
        id: UUID,
        period: String,
        date: String,
        startDate: String?,
        endDate: String?,
        isFavorite: Bool = false,
        customName: String? = nil,
        usesDynamicName: Bool = true,
        createdAt: String,
        deletedAt: String?,
        revision: Int64
    ) {
        self.id = id
        self.period = period
        self.date = date
        self.startDate = startDate
        self.endDate = endDate
        self.isFavorite = isFavorite
        self.customName = customName
        self.usesDynamicName = usesDynamicName
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.revision = revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        period = try container.decode(String.self, forKey: .period)
        date = try container.decode(String.self, forKey: .date)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        usesDynamicName = try container.decodeIfPresent(Bool.self, forKey: .usesDynamicName) ?? false
        createdAt = try container.decode(String.self, forKey: .createdAt)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        revision = try container.decode(Int64.self, forKey: .revision)
    }
}

/// A row from the `tasks` table.
struct ServerTaskRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let body: String?
    let priority: String
    let dueDate: String?
    let date: String?
    let period: String?
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, body, priority, date, period, status, revision
        case dueDate = "due_date"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }

    init(
        id: UUID,
        title: String,
        body: String? = nil,
        priority: String = "none",
        dueDate: String? = nil,
        date: String?,
        period: String?,
        status: String,
        createdAt: String,
        deletedAt: String?,
        revision: Int64
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.priority = priority
        self.dueDate = dueDate
        self.date = date
        self.period = period
        self.status = status
        self.createdAt = createdAt
        self.deletedAt = deletedAt
        self.revision = revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "none"
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        period = try container.decodeIfPresent(String.self, forKey: .period)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        revision = try container.decode(Int64.self, forKey: .revision)
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
    let content: String
    let createdAt: String
    let modifiedAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, title, content, revision
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
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

    /// Serializes settings into JSON record data for the outbox.
    ///
    /// Uses the model's LWW timestamps if available, falling back to the
    /// provided timestamp for new records.
    static func serializeSettings(
        _ settings: DataModel.Settings,
        deviceId: UUID,
        timestamp: Date
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": settings.id.uuidString,
            "device_id": deviceId.uuidString,
            "bujo_mode": settings.bujoMode.rawValue,
            "first_weekday": settings.firstWeekday,
            "created_at": SyncDateFormatting.formatTimestamp(settings.createdDate),
            "deleted_at": settings.deletedAt.map { SyncDateFormatting.formatTimestamp($0) },
            "bujo_mode_updated_at": settings.bujoModeUpdatedAt
                .map { SyncDateFormatting.formatTimestamp($0) } ?? ts,
            "first_weekday_updated_at": settings.firstWeekdayUpdatedAt
                .map { SyncDateFormatting.formatTimestamp($0) } ?? ts
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a spread into JSON record data for the outbox.
    static func serializeSpread(
        _ spread: DataModel.Spread,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": spread.id.uuidString,
            "device_id": deviceId.uuidString,
            "period": spread.period.rawValue,
            "date": SyncDateFormatting.formatDate(spread.date),
            "start_date": spread.startDate.map { SyncDateFormatting.formatDate($0) },
            "end_date": spread.endDate.map { SyncDateFormatting.formatDate($0) },
            "is_favorite": spread.isFavorite,
            "custom_name": spread.customName,
            "uses_dynamic_name": spread.usesDynamicName,
            "created_at": SyncDateFormatting.formatTimestamp(spread.createdDate),
            "deleted_at": (deletedAt ?? spread.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "period_updated_at": SyncDateFormatting.formatTimestamp(spread.periodUpdatedAt ?? timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(spread.dateUpdatedAt ?? timestamp),
            "start_date_updated_at": SyncDateFormatting.formatTimestamp(spread.startDateUpdatedAt ?? timestamp),
            "end_date_updated_at": SyncDateFormatting.formatTimestamp(spread.endDateUpdatedAt ?? timestamp),
            "is_favorite_updated_at": SyncDateFormatting.formatTimestamp(spread.isFavoriteUpdatedAt ?? timestamp),
            "custom_name_updated_at": SyncDateFormatting.formatTimestamp(spread.customNameUpdatedAt ?? timestamp),
            "uses_dynamic_name_updated_at": SyncDateFormatting.formatTimestamp(spread.usesDynamicNameUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a task into JSON record data for the outbox.
    static func serializeTask(
        _ task: DataModel.Task,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": task.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": task.title,
            "body": task.body,
            "priority": task.priority.rawValue,
            "due_date": task.dueDate.map { SyncDateFormatting.formatDate($0) },
            "date": task.hasPreferredAssignment ? SyncDateFormatting.formatDate(task.date) : nil,
            "period": task.hasPreferredAssignment ? task.period.rawValue : nil,
            "status": task.status.rawValue,
            "created_at": SyncDateFormatting.formatTimestamp(task.createdDate),
            "deleted_at": (deletedAt ?? task.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(task.titleUpdatedAt ?? timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(task.dateUpdatedAt ?? timestamp),
            "period_updated_at": SyncDateFormatting.formatTimestamp(task.periodUpdatedAt ?? timestamp),
            "status_updated_at": SyncDateFormatting.formatTimestamp(task.statusUpdatedAt ?? timestamp),
            "body_updated_at": SyncDateFormatting.formatTimestamp(task.bodyUpdatedAt ?? timestamp),
            "priority_updated_at": SyncDateFormatting.formatTimestamp(task.priorityUpdatedAt ?? timestamp),
            "due_date_updated_at": SyncDateFormatting.formatTimestamp(task.dueDateUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a note into JSON record data for the outbox.
    static func serializeNote(
        _ note: DataModel.Note,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": note.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": note.title,
            "content": note.content,
            "date": SyncDateFormatting.formatDate(note.date),
            "period": note.period.rawValue,
            "status": note.status.rawValue,
            "created_at": SyncDateFormatting.formatTimestamp(note.createdDate),
            "deleted_at": (deletedAt ?? note.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(note.titleUpdatedAt ?? timestamp),
            "content_updated_at": SyncDateFormatting.formatTimestamp(note.contentUpdatedAt ?? timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(note.dateUpdatedAt ?? timestamp),
            "period_updated_at": SyncDateFormatting.formatTimestamp(note.periodUpdatedAt ?? timestamp),
            "status_updated_at": SyncDateFormatting.formatTimestamp(note.statusUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a collection into JSON record data for the outbox.
    static func serializeCollection(
        _ collection: DataModel.Collection,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": collection.id.uuidString,
            "device_id": deviceId.uuidString,
            "title": collection.title,
            "content": collection.content,
            "created_at": SyncDateFormatting.formatTimestamp(collection.createdDate),
            "modified_at": SyncDateFormatting.formatTimestamp(collection.modifiedDate),
            "deleted_at": (deletedAt ?? collection.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(collection.titleUpdatedAt ?? timestamp),
            "content_updated_at": SyncDateFormatting.formatTimestamp(collection.contentUpdatedAt ?? timestamp)
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
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": assignment.id.uuidString,
            "device_id": deviceId.uuidString,
            "task_id": taskId.uuidString,
            "period": assignment.period.rawValue,
            "date": SyncDateFormatting.formatDate(assignment.date),
            "status": assignment.status.rawValue,
            "created_at": ts,
            "deleted_at": deletedAt.map { SyncDateFormatting.formatTimestamp($0) },
            "status_updated_at": SyncDateFormatting.formatTimestamp(assignment.statusUpdatedAt ?? timestamp)
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
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": assignment.id.uuidString,
            "device_id": deviceId.uuidString,
            "note_id": noteId.uuidString,
            "period": assignment.period.rawValue,
            "date": SyncDateFormatting.formatDate(assignment.date),
            "status": assignment.status.rawValue,
            "created_at": ts,
            "deleted_at": deletedAt.map { SyncDateFormatting.formatTimestamp($0) },
            "status_updated_at": SyncDateFormatting.formatTimestamp(assignment.statusUpdatedAt ?? timestamp)
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
        case .settings:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let bujoMode = json["bujo_mode"] as? String,
                  let firstWeekday = json["first_weekday"] as? Int,
                  let createdAt = json["created_at"] as? String,
                  let bujoModeUpdatedAt = json["bujo_mode_updated_at"] as? String,
                  let firstWeekdayUpdatedAt = json["first_weekday_updated_at"] as? String else {
                return nil
            }
            let params = MergeSettingsParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pBujoMode: bujoMode, pFirstWeekday: firstWeekday,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pBujoModeUpdatedAt: bujoModeUpdatedAt,
                pFirstWeekdayUpdatedAt: firstWeekdayUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .spread:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let period = json["period"] as? String,
                  let date = json["date"] as? String,
                  let isFavorite = json["is_favorite"] as? Bool,
                  let usesDynamicName = json["uses_dynamic_name"] as? Bool,
                  let createdAt = json["created_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let startDateUpdatedAt = json["start_date_updated_at"] as? String,
                  let endDateUpdatedAt = json["end_date_updated_at"] as? String,
                  let isFavoriteUpdatedAt = json["is_favorite_updated_at"] as? String,
                  let customNameUpdatedAt = json["custom_name_updated_at"] as? String,
                  let usesDynamicNameUpdatedAt = json["uses_dynamic_name_updated_at"] as? String else {
                return nil
            }
            let params = MergeSpreadParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pPeriod: period, pDate: date,
                pStartDate: json["start_date"] as? String,
                pEndDate: json["end_date"] as? String,
                pIsFavorite: isFavorite,
                pCustomName: json["custom_name"] as? String,
                pUsesDynamicName: usesDynamicName,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pPeriodUpdatedAt: periodUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pStartDateUpdatedAt: startDateUpdatedAt,
                pEndDateUpdatedAt: endDateUpdatedAt,
                pIsFavoriteUpdatedAt: isFavoriteUpdatedAt,
                pCustomNameUpdatedAt: customNameUpdatedAt,
                pUsesDynamicNameUpdatedAt: usesDynamicNameUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .task:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let title = json["title"] as? String,
                  let priority = json["priority"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String,
                  let bodyUpdatedAt = json["body_updated_at"] as? String,
                  let priorityUpdatedAt = json["priority_updated_at"] as? String,
                  let dueDateUpdatedAt = json["due_date_updated_at"] as? String else {
                return nil
            }
            let params = MergeTaskParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTitle: title,
                pBody: json["body"] as? String,
                pPriority: priority,
                pDueDate: json["due_date"] as? String,
                pDate: json["date"] as? String,
                pPeriod: json["period"] as? String,
                pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pPeriodUpdatedAt: periodUpdatedAt,
                pStatusUpdatedAt: statusUpdatedAt,
                pBodyUpdatedAt: bodyUpdatedAt,
                pPriorityUpdatedAt: priorityUpdatedAt,
                pDueDateUpdatedAt: dueDateUpdatedAt
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
                  let content = json["content"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let modifiedAt = json["modified_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String,
                  let contentUpdatedAt = json["content_updated_at"] as? String else {
                return nil
            }
            let params = MergeCollectionParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pTitle: title, pContent: content,
                pCreatedAt: createdAt, pModifiedAt: modifiedAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt,
                pContentUpdatedAt: contentUpdatedAt
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
        spread.isFavorite = row.isFavorite
        spread.customName = row.customName
        spread.usesDynamicName = row.usesDynamicName
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
                calendar: calendar, createdDate: createdAt,
                isFavorite: row.isFavorite,
                customName: row.customName,
                usesDynamicName: row.usesDynamicName
            )
        }

        return DataModel.Spread(
            id: row.id, period: period, date: date,
            calendar: calendar, createdDate: createdAt,
            isFavorite: row.isFavorite,
            customName: row.customName,
            usesDynamicName: row.usesDynamicName
        )
    }

    /// Applies a server task row to a local task model.
    static func applyTaskRow(_ row: ServerTaskRow, to task: DataModel.Task) -> Bool {
        guard row.deletedAt == nil else { return false }
        task.title = row.title
        task.body = row.body
        if let priority = DataModel.Task.Priority(rawValue: row.priority) { task.priority = priority }
        task.dueDate = row.dueDate.flatMap { SyncDateFormatting.parseDate($0) }
        if let rowDate = row.date, let date = SyncDateFormatting.parseDate(rowDate) {
            task.date = date
        }
        if let rowPeriod = row.period, let period = Period(rawValue: rowPeriod) {
            task.period = period
        }
        task.hasPreferredAssignment = row.date != nil && row.period != nil
        if let status = DataModel.Task.Status(rawValue: row.status) { task.status = status }
        return true
    }

    /// Creates a new local task from a server row.
    static func createTask(from row: ServerTaskRow) -> DataModel.Task? {
        guard row.deletedAt == nil,
              let status = DataModel.Task.Status(rawValue: row.status),
              let priority = DataModel.Task.Priority(rawValue: row.priority),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        guard row.date == nil || row.date.flatMap({ SyncDateFormatting.parseDate($0) }) != nil,
              row.period == nil || row.period.flatMap({ Period(rawValue: $0) }) != nil else {
            return nil
        }
        let parsedDate = row.date.flatMap { SyncDateFormatting.parseDate($0) } ?? createdAt
        let parsedPeriod = row.period.flatMap { Period(rawValue: $0) } ?? .day
        return DataModel.Task(
            id: row.id,
            title: row.title,
            body: row.body,
            priority: priority,
            dueDate: row.dueDate.flatMap { SyncDateFormatting.parseDate($0) },
            createdDate: createdAt,
            date: parsedDate,
            period: parsedPeriod,
            hasPreferredAssignment: row.date != nil && row.period != nil,
            status: status
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
        guard row.deletedAt == nil,
              let modifiedAt = SyncDateFormatting.parseTimestamp(row.modifiedAt) else {
            return false
        }
        collection.title = row.title
        collection.content = row.content
        collection.modifiedDate = modifiedAt
        return true
    }

    /// Creates a new local collection from a server row.
    static func createCollection(from row: ServerCollectionRow) -> DataModel.Collection? {
        guard row.deletedAt == nil,
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt),
              let modifiedAt = SyncDateFormatting.parseTimestamp(row.modifiedAt) else {
            return nil
        }
        return DataModel.Collection(
            id: row.id,
            title: row.title,
            content: row.content,
            createdDate: createdAt,
            modifiedDate: modifiedAt
        )
    }

    /// Converts a server task assignment row to a local TaskAssignment value.
    static func createTaskAssignment(from row: ServerTaskAssignmentRow) -> TaskAssignment? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let status = DataModel.Task.Status(rawValue: row.status) else {
            return nil
        }
        return TaskAssignment(id: row.id, period: period, date: date, status: status)
    }

    /// Converts a server note assignment row to a local NoteAssignment value.
    static func createNoteAssignment(from row: ServerNoteAssignmentRow) -> NoteAssignment? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let status = DataModel.Note.Status(rawValue: row.status) else {
            return nil
        }
        return NoteAssignment(id: row.id, period: period, date: date, status: status)
    }

    /// Applies a server settings row to a local settings model.
    static func applySettingsRow(_ row: ServerSettingsRow, to settings: DataModel.Settings) -> Bool {
        guard row.deletedAt == nil else { return false }
        if let bujoMode = BujoMode(rawValue: row.bujoMode) { settings.bujoMode = bujoMode }
        settings.firstWeekday = row.firstWeekday
        settings.revision = row.revision
        return true
    }

    /// Creates a new local settings from a server row.
    static func createSettings(from row: ServerSettingsRow) -> DataModel.Settings? {
        guard row.deletedAt == nil,
              let bujoMode = BujoMode(rawValue: row.bujoMode),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Settings(
            id: row.id,
            bujoMode: bujoMode,
            firstWeekday: row.firstWeekday,
            createdDate: createdAt,
            revision: row.revision
        )
    }
}
