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

/// Parameters for the `merge_entry` RPC. Covers both Task and Note shapes — fields that
/// don't apply to a given type (e.g. `pBody` for a note, `pContent` for a task) are nil.
struct MergeEntryParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pType: String
    let pTitle: String
    let pContent: String?
    let pDate: String?
    let pPeriod: String?
    let pStatus: String
    let pBody: String?
    let pPriority: String?
    let pDueDate: String?
    let pScheduledTime: String?
    let pListId: String?
    let pCreatedAt: String
    let pDeletedAt: String?
    let pTitleUpdatedAt: String
    let pContentUpdatedAt: String
    let pDateUpdatedAt: String
    let pPeriodUpdatedAt: String
    let pStatusUpdatedAt: String
    let pBodyUpdatedAt: String
    let pPriorityUpdatedAt: String
    let pDueDateUpdatedAt: String
    let pScheduledTimeUpdatedAt: String
    let pListUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pType = "p_type"
        case pTitle = "p_title"
        case pContent = "p_content"
        case pDate = "p_date"
        case pPeriod = "p_period"
        case pStatus = "p_status"
        case pBody = "p_body"
        case pPriority = "p_priority"
        case pDueDate = "p_due_date"
        case pScheduledTime = "p_scheduled_time"
        case pListId = "p_list_id"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pTitleUpdatedAt = "p_title_updated_at"
        case pContentUpdatedAt = "p_content_updated_at"
        case pDateUpdatedAt = "p_date_updated_at"
        case pPeriodUpdatedAt = "p_period_updated_at"
        case pStatusUpdatedAt = "p_status_updated_at"
        case pBodyUpdatedAt = "p_body_updated_at"
        case pPriorityUpdatedAt = "p_priority_updated_at"
        case pDueDateUpdatedAt = "p_due_date_updated_at"
        case pScheduledTimeUpdatedAt = "p_scheduled_time_updated_at"
        case pListUpdatedAt = "p_list_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pType, forKey: .pType)
        try container.encode(pTitle, forKey: .pTitle)
        try container.encode(pContent, forKey: .pContent)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pBody, forKey: .pBody)
        try container.encode(pPriority, forKey: .pPriority)
        try container.encode(pDueDate, forKey: .pDueDate)
        try container.encode(pScheduledTime, forKey: .pScheduledTime)
        try container.encode(pListId, forKey: .pListId)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pTitleUpdatedAt, forKey: .pTitleUpdatedAt)
        try container.encode(pContentUpdatedAt, forKey: .pContentUpdatedAt)
        try container.encode(pDateUpdatedAt, forKey: .pDateUpdatedAt)
        try container.encode(pPeriodUpdatedAt, forKey: .pPeriodUpdatedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
        try container.encode(pBodyUpdatedAt, forKey: .pBodyUpdatedAt)
        try container.encode(pPriorityUpdatedAt, forKey: .pPriorityUpdatedAt)
        try container.encode(pDueDateUpdatedAt, forKey: .pDueDateUpdatedAt)
        try container.encode(pScheduledTimeUpdatedAt, forKey: .pScheduledTimeUpdatedAt)
        try container.encode(pListUpdatedAt, forKey: .pListUpdatedAt)
    }
}

/// Parameters for the `merge_list` RPC.
struct MergeListParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pName: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pNameUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pName = "p_name"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pNameUpdatedAt = "p_name_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pName, forKey: .pName)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pNameUpdatedAt, forKey: .pNameUpdatedAt)
    }
}

/// Parameters for the `merge_tag` RPC.
struct MergeTagParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pName: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pNameUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pName = "p_name"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
        case pNameUpdatedAt = "p_name_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pId, forKey: .pId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pDeviceId, forKey: .pDeviceId)
        try container.encode(pName, forKey: .pName)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pNameUpdatedAt, forKey: .pNameUpdatedAt)
    }
}

/// Parameters for the `merge_entry_tag` RPC.
struct MergeEntryTagParams: Encodable, Sendable {
    let pEntryId: String
    let pTagId: String
    let pUserId: String
    let pCreatedAt: String
    let pDeletedAt: String?

    enum CodingKeys: String, CodingKey {
        case pEntryId = "p_entry_id"
        case pTagId = "p_tag_id"
        case pUserId = "p_user_id"
        case pCreatedAt = "p_created_at"
        case pDeletedAt = "p_deleted_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pEntryId, forKey: .pEntryId)
        try container.encode(pTagId, forKey: .pTagId)
        try container.encode(pUserId, forKey: .pUserId)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
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

/// Parameters for the `merge_assignment` RPC. Covers both task and note assignments —
/// `pEntryType` discriminates which `entries` row `pEntryId` points at.
struct MergeAssignmentParams: Encodable, Sendable {
    let pId: String
    let pUserId: String
    let pDeviceId: String
    let pEntryId: String
    let pEntryType: String
    let pPeriod: String
    let pDate: String
    let pSpreadId: String?
    let pStatus: String
    let pCreatedAt: String
    let pDeletedAt: String?
    let pStatusUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case pId = "p_id"
        case pUserId = "p_user_id"
        case pDeviceId = "p_device_id"
        case pEntryId = "p_entry_id"
        case pEntryType = "p_entry_type"
        case pPeriod = "p_period"
        case pDate = "p_date"
        case pSpreadId = "p_spread_id"
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
        try container.encode(pEntryId, forKey: .pEntryId)
        try container.encode(pEntryType, forKey: .pEntryType)
        try container.encode(pPeriod, forKey: .pPeriod)
        try container.encode(pDate, forKey: .pDate)
        try container.encode(pSpreadId, forKey: .pSpreadId)
        try container.encode(pStatus, forKey: .pStatus)
        try container.encode(pCreatedAt, forKey: .pCreatedAt)
        try container.encode(pDeletedAt, forKey: .pDeletedAt)
        try container.encode(pStatusUpdatedAt, forKey: .pStatusUpdatedAt)
    }
}

/// Parameters for a `merge_X_batch` RPC: a jsonb array of per-row params.
struct BatchMergeParams: Encodable, Sendable {
    let rows: [AnyEncodable]

    enum CodingKeys: String, CodingKey {
        case rows = "p_rows"
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

/// A row from the `entries` table. Covers both Task and Note shapes — fields that don't
/// apply to `type` (e.g. `content` for a task, `body`/`priority`/`dueDate` for a note) are nil.
struct ServerEntryRow: Decodable, Sendable {
    let id: UUID
    let type: String
    let title: String
    let content: String?
    let date: String?
    let period: String?
    let status: String
    let body: String?
    let priority: String?
    let dueDate: String?
    let scheduledTime: String?
    let listId: UUID?
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, type, title, content, date, period, status, body, priority, revision
        case dueDate = "due_date"
        case scheduledTime = "scheduled_time"
        case listId = "list_id"
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

/// A row from the `assignments` table. `entryType` discriminates whether `entryId`
/// points at a task or note entry.
struct ServerAssignmentRow: Decodable, Sendable {
    let id: UUID
    let entryId: UUID
    let entryType: String
    let period: String
    let date: String
    let spreadId: UUID?
    let status: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, period, date, status, revision
        case entryId = "entry_id"
        case entryType = "entry_type"
        case spreadId = "spread_id"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `lists` table.
struct ServerListRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, revision
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `tags` table.
struct ServerTagRow: Decodable, Sendable {
    let id: UUID
    let name: String
    let createdAt: String
    let deletedAt: String?
    let revision: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, revision
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

/// A row from the `entry_tags` join table.
struct ServerEntryTagRow: Decodable, Sendable {
    let entryId: UUID
    let tagId: UUID
    let createdAt: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case tagId = "tag_id"
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
            "bujo_mode": "conventional",
            "first_weekday": settings.firstWeekday,
            "created_at": SyncDateFormatting.formatTimestamp(settings.createdDate),
            "deleted_at": settings.deletedAt.map { SyncDateFormatting.formatTimestamp($0) },
            "bujo_mode_updated_at": ts,
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

    /// Serializes a task entry into JSON record data for the outbox.
    static func serializeTaskEntry(
        _ task: DataModel.Task,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": task.id.uuidString,
            "device_id": deviceId.uuidString,
            "type": "task",
            "title": task.title,
            "content": nil,
            "date": task.date.map { SyncDateFormatting.formatDate($0) },
            "period": task.period?.rawValue,
            "status": task.status.rawValue,
            "body": task.body,
            "priority": task.priority.rawValue,
            "due_date": task.dueDate.map { SyncDateFormatting.formatDate($0) },
            "scheduled_time": task.scheduledTime.map { SyncDateFormatting.formatTimestamp($0) },
            "list_id": task.list?.id.uuidString,
            "created_at": SyncDateFormatting.formatTimestamp(task.createdDate),
            "deleted_at": (deletedAt ?? task.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(task.titleUpdatedAt ?? timestamp),
            "content_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(task.dateUpdatedAt ?? timestamp),
            "period_updated_at": SyncDateFormatting.formatTimestamp(task.periodUpdatedAt ?? timestamp),
            "status_updated_at": SyncDateFormatting.formatTimestamp(task.statusUpdatedAt ?? timestamp),
            "body_updated_at": SyncDateFormatting.formatTimestamp(task.bodyUpdatedAt ?? timestamp),
            "priority_updated_at": SyncDateFormatting.formatTimestamp(task.priorityUpdatedAt ?? timestamp),
            "due_date_updated_at": SyncDateFormatting.formatTimestamp(task.dueDateUpdatedAt ?? timestamp),
            "scheduled_time_updated_at": SyncDateFormatting.formatTimestamp(task.scheduledTimeUpdatedAt ?? timestamp),
            "list_updated_at": SyncDateFormatting.formatTimestamp(task.listUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a note entry into JSON record data for the outbox.
    static func serializeNoteEntry(
        _ note: DataModel.Note,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": note.id.uuidString,
            "device_id": deviceId.uuidString,
            "type": "note",
            "title": note.title,
            "content": note.content,
            "date": note.date.map { SyncDateFormatting.formatDate($0) },
            "period": note.period.rawValue,
            "status": note.status.rawValue,
            "body": nil,
            "priority": nil,
            "due_date": nil,
            "scheduled_time": nil,
            "list_id": note.list?.id.uuidString,
            "created_at": SyncDateFormatting.formatTimestamp(note.createdDate),
            "deleted_at": (deletedAt ?? note.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(note.titleUpdatedAt ?? timestamp),
            "content_updated_at": SyncDateFormatting.formatTimestamp(note.contentUpdatedAt ?? timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(note.dateUpdatedAt ?? timestamp),
            "period_updated_at": SyncDateFormatting.formatTimestamp(note.periodUpdatedAt ?? timestamp),
            "status_updated_at": SyncDateFormatting.formatTimestamp(note.statusUpdatedAt ?? timestamp),
            "body_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "priority_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "due_date_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "scheduled_time_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "list_updated_at": SyncDateFormatting.formatTimestamp(note.listUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a list into JSON record data for the outbox.
    static func serializeList(
        _ list: DataModel.List,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": list.id.uuidString,
            "device_id": deviceId.uuidString,
            "name": list.name,
            "created_at": SyncDateFormatting.formatTimestamp(list.createdDate),
            "deleted_at": (deletedAt ?? list.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "name_updated_at": SyncDateFormatting.formatTimestamp(list.nameUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes a tag into JSON record data for the outbox.
    static func serializeTag(
        _ tag: DataModel.Tag,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "id": tag.id.uuidString,
            "device_id": deviceId.uuidString,
            "name": tag.name,
            "created_at": SyncDateFormatting.formatTimestamp(tag.createdDate),
            "deleted_at": (deletedAt ?? tag.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "name_updated_at": SyncDateFormatting.formatTimestamp(tag.nameUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }

    /// Serializes an entry-tag join row into JSON record data for the outbox.
    ///
    /// The server identifies this row by (entry_id, tag_id) compound key.
    static func serializeEntryTag(
        entryId: UUID,
        tagId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let record: [String: Any?] = [
            "entry_id": entryId.uuidString,
            "tag_id": tagId.uuidString,
            "created_at": SyncDateFormatting.formatTimestamp(timestamp),
            "deleted_at": deletedAt.map { SyncDateFormatting.formatTimestamp($0) }
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

    /// Serializes an assignment into JSON record data for the outbox.
    ///
    /// - Parameters:
    ///   - entryId: The id of the task or note entry this assignment belongs to.
    ///   - entryType: `.task` or `.note` — discriminates which `entries` row `entryId` points at.
    static func serializeAssignment(
        _ assignment: Assignment,
        entryId: UUID,
        entryType: EntryType,
        deviceId: UUID,
        timestamp: Date,
        deletedAt: Date? = nil
    ) -> Data? {
        let ts = SyncDateFormatting.formatTimestamp(timestamp)
        let record: [String: Any?] = [
            "id": assignment.id.uuidString,
            "device_id": deviceId.uuidString,
            "entry_id": entryId.uuidString,
            "entry_type": entryType.rawValue,
            "period": assignment.period.rawValue,
            "date": SyncDateFormatting.formatDate(assignment.date),
            "spread_id": assignment.spreadID?.uuidString,
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

        case .entry:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let type = json["type"] as? String,
                  let title = json["title"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let titleUpdatedAt = json["title_updated_at"] as? String,
                  let contentUpdatedAt = json["content_updated_at"] as? String,
                  let dateUpdatedAt = json["date_updated_at"] as? String,
                  let periodUpdatedAt = json["period_updated_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String,
                  let bodyUpdatedAt = json["body_updated_at"] as? String,
                  let priorityUpdatedAt = json["priority_updated_at"] as? String,
                  let dueDateUpdatedAt = json["due_date_updated_at"] as? String,
                  let scheduledTimeUpdatedAt = json["scheduled_time_updated_at"] as? String,
                  let listUpdatedAt = json["list_updated_at"] as? String else {
                return nil
            }
            let params = MergeEntryParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pType: type,
                pTitle: title,
                pContent: json["content"] as? String,
                pDate: json["date"] as? String,
                pPeriod: json["period"] as? String,
                pStatus: status,
                pBody: json["body"] as? String,
                pPriority: json["priority"] as? String,
                pDueDate: json["due_date"] as? String,
                pScheduledTime: json["scheduled_time"] as? String,
                pListId: json["list_id"] as? String,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pTitleUpdatedAt: titleUpdatedAt,
                pContentUpdatedAt: contentUpdatedAt,
                pDateUpdatedAt: dateUpdatedAt,
                pPeriodUpdatedAt: periodUpdatedAt,
                pStatusUpdatedAt: statusUpdatedAt,
                pBodyUpdatedAt: bodyUpdatedAt,
                pPriorityUpdatedAt: priorityUpdatedAt,
                pDueDateUpdatedAt: dueDateUpdatedAt,
                pScheduledTimeUpdatedAt: scheduledTimeUpdatedAt,
                pListUpdatedAt: listUpdatedAt
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

        case .assignment:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let entryId = json["entry_id"] as? String,
                  let entryType = json["entry_type"] as? String,
                  let period = json["period"] as? String,
                  let date = json["date"] as? String,
                  let status = json["status"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let statusUpdatedAt = json["status_updated_at"] as? String else {
                return nil
            }
            let params = MergeAssignmentParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pEntryId: entryId,
                pEntryType: entryType,
                pPeriod: period,
                pDate: date,
                pSpreadId: json["spread_id"] as? String,
                pStatus: status,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pStatusUpdatedAt: statusUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .list:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let name = json["name"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let nameUpdatedAt = json["name_updated_at"] as? String else {
                return nil
            }
            let params = MergeListParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pName: name,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pNameUpdatedAt: nameUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .tag:
            guard let id = json["id"] as? String,
                  let deviceId = json["device_id"] as? String,
                  let name = json["name"] as? String,
                  let createdAt = json["created_at"] as? String,
                  let nameUpdatedAt = json["name_updated_at"] as? String else {
                return nil
            }
            let params = MergeTagParams(
                pId: id, pUserId: uid, pDeviceId: deviceId,
                pName: name,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String,
                pNameUpdatedAt: nameUpdatedAt
            )
            return (entityType.mergeRPCName, params)

        case .entryTag:
            guard let entryId = json["entry_id"] as? String,
                  let tagId = json["tag_id"] as? String,
                  let createdAt = json["created_at"] as? String else {
                return nil
            }
            let params = MergeEntryTagParams(
                pEntryId: entryId,
                pTagId: tagId,
                pUserId: uid,
                pCreatedAt: createdAt,
                pDeletedAt: json["deleted_at"] as? String
            )
            return (entityType.mergeRPCName, params)
        }
    }

    /// Wraps a batch of mutations' record data into the `{"p_rows": [...]}` payload for the
    /// batch merge RPC, reusing `buildMergeParams` unchanged for each row's parameters.
    ///
    /// Mutations whose `recordData` fails to parse are excluded from the payload and returned
    /// separately via `failedMutationIDs`, so the caller can delete them from the outbox before
    /// issuing the batch RPC call — unchanged from today's per-mutation filtering behavior.
    static func buildBatchMergeParams(
        entityType: SyncEntityType,
        mutations: [(mutationID: UUID, recordData: Data)],
        userId: UUID
    ) -> (rpcName: String, params: BatchMergeParams, failedMutationIDs: [UUID]) {
        var rows: [AnyEncodable] = []
        var failedMutationIDs: [UUID] = []

        for mutation in mutations {
            guard let (_, params) = buildMergeParams(
                entityType: entityType, recordData: mutation.recordData, userId: userId
            ) else {
                failedMutationIDs.append(mutation.mutationID)
                continue
            }
            rows.append(AnyEncodable(params))
        }

        return (entityType.mergeBatchRPCName, BatchMergeParams(rows: rows), failedMutationIDs)
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

    /// Applies a server entry row to a local task model.
    static func applyTaskRow(_ row: ServerEntryRow, to task: DataModel.Task) -> Bool {
        guard row.deletedAt == nil else { return false }
        task.title = row.title
        task.body = row.body
        if let priority = row.priority.flatMap({ DataModel.Task.Priority(rawValue: $0) }) {
            task.priority = priority
        }
        task.dueDate = row.dueDate.flatMap { SyncDateFormatting.parseDate($0) }
        task.scheduledTime = row.scheduledTime.flatMap { SyncDateFormatting.parseTimestamp($0) }
        task.date = row.date.flatMap { SyncDateFormatting.parseDate($0) }
        task.period = row.period.flatMap { Period(rawValue: $0) }
        if let status = EntryStatus(rawValue: row.status) { task.status = status }
        return true
    }

    /// Creates a new local task from a server entry row.
    static func createTask(from row: ServerEntryRow) -> DataModel.Task? {
        guard row.deletedAt == nil,
              let status = EntryStatus(rawValue: row.status),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        guard row.date == nil || row.date.flatMap({ SyncDateFormatting.parseDate($0) }) != nil,
              row.period == nil || row.period.flatMap({ Period(rawValue: $0) }) != nil else {
            return nil
        }
        let priority = row.priority.flatMap { DataModel.Task.Priority(rawValue: $0) } ?? .none
        return DataModel.Task(
            id: row.id,
            title: row.title,
            body: row.body,
            priority: priority,
            dueDate: row.dueDate.flatMap { SyncDateFormatting.parseDate($0) },
            scheduledTime: row.scheduledTime.flatMap { SyncDateFormatting.parseTimestamp($0) },
            createdDate: createdAt,
            date: row.date.flatMap { SyncDateFormatting.parseDate($0) },
            period: row.period.flatMap { Period(rawValue: $0) },
            status: status
        )
    }

    /// Applies a server entry row to a local note model.
    static func applyNoteRow(_ row: ServerEntryRow, to note: DataModel.Note) -> Bool {
        guard row.deletedAt == nil else { return false }
        note.title = row.title
        note.content = row.content ?? ""
        note.date = row.date.flatMap { SyncDateFormatting.parseDate($0) }
        if let period = row.period.flatMap({ Period(rawValue: $0) }) { note.period = period }
        if let status = EntryStatus(rawValue: row.status) { note.status = status }
        return true
    }

    /// Creates a new local note from a server entry row.
    static func createNote(from row: ServerEntryRow) -> DataModel.Note? {
        guard row.deletedAt == nil,
              let period = row.period.flatMap({ Period(rawValue: $0) }),
              let status = EntryStatus(rawValue: row.status),
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Note(
            id: row.id, title: row.title, content: row.content ?? "",
            createdDate: createdAt,
            date: row.date.flatMap { SyncDateFormatting.parseDate($0) },
            period: period, status: status
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

    /// Converts a server assignment row to a local Assignment value.
    static func createAssignment(from row: ServerAssignmentRow) -> Assignment? {
        guard row.deletedAt == nil,
              let period = Period(rawValue: row.period),
              let date = SyncDateFormatting.parseDate(row.date),
              let status = EntryStatus(rawValue: row.status) else {
            return nil
        }
        return Assignment(
            id: row.id,
            period: period,
            date: date,
            spreadID: row.spreadId,
            status: status
        )
    }

    /// Applies a server settings row to a local settings model.
    static func applySettingsRow(_ row: ServerSettingsRow, to settings: DataModel.Settings) -> Bool {
        guard row.deletedAt == nil else { return false }
        settings.firstWeekday = row.firstWeekday
        settings.revision = row.revision
        return true
    }

    /// Creates a new local settings from a server row.
    static func createSettings(from row: ServerSettingsRow) -> DataModel.Settings? {
        guard row.deletedAt == nil,
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Settings(
            id: row.id,
            firstWeekday: row.firstWeekday,
            createdDate: createdAt,
            revision: row.revision
        )
    }

    /// Creates a new local list from a server row.
    static func createList(from row: ServerListRow) -> DataModel.List? {
        guard row.deletedAt == nil,
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.List(id: row.id, name: row.name, createdDate: createdAt)
    }

    /// Applies a server list row to a local list model.
    static func applyListRow(_ row: ServerListRow, to list: DataModel.List) -> Bool {
        guard row.deletedAt == nil else { return false }
        list.name = row.name
        list.revision = row.revision
        return true
    }

    /// Creates a new local tag from a server row.
    static func createTag(from row: ServerTagRow) -> DataModel.Tag? {
        guard row.deletedAt == nil,
              let createdAt = SyncDateFormatting.parseTimestamp(row.createdAt) else {
            return nil
        }
        return DataModel.Tag(id: row.id, name: row.name, createdDate: createdAt)
    }

    /// Applies a server tag row to a local tag model.
    static func applyTagRow(_ row: ServerTagRow, to tag: DataModel.Tag) -> Bool {
        guard row.deletedAt == nil else { return false }
        tag.name = row.name
        tag.revision = row.revision
        return true
    }
}
