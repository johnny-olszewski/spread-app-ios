import Foundation

extension DataModel.Task: SerializableData {
    static var entityType: SyncEntityType { .entry }

    func serialize(deviceId: UUID, timestamp: Date, deletedAt: Date? = nil) -> Data? {
        let record: [String: Any?] = [
            "id": id.uuidString,
            "device_id": deviceId.uuidString,
            "type": "task",
            "title": title,
            "content": nil,
            "date": date.map { SyncDateFormatting.formatDate($0) },
            "period": period?.rawValue,
            "status": status.rawValue,
            "body": body,
            "priority": priority.rawValue,
            "due_date": dueDate.map { SyncDateFormatting.formatDate($0) },
            "scheduled_time": scheduledTime.map { SyncDateFormatting.formatTimestamp($0) },
            "list_id": list?.id.uuidString,
            "created_at": SyncDateFormatting.formatTimestamp(createdDate),
            "deleted_at": (deletedAt ?? self.deletedAt).map { SyncDateFormatting.formatTimestamp($0) },
            "title_updated_at": SyncDateFormatting.formatTimestamp(titleUpdatedAt ?? timestamp),
            "content_updated_at": SyncDateFormatting.formatTimestamp(timestamp),
            "date_updated_at": SyncDateFormatting.formatTimestamp(dateUpdatedAt ?? timestamp),
            "period_updated_at": SyncDateFormatting.formatTimestamp(periodUpdatedAt ?? timestamp),
            "status_updated_at": SyncDateFormatting.formatTimestamp(statusUpdatedAt ?? timestamp),
            "body_updated_at": SyncDateFormatting.formatTimestamp(bodyUpdatedAt ?? timestamp),
            "priority_updated_at": SyncDateFormatting.formatTimestamp(priorityUpdatedAt ?? timestamp),
            "due_date_updated_at": SyncDateFormatting.formatTimestamp(dueDateUpdatedAt ?? timestamp),
            // Falls back to createdDate, not `timestamp` (now()), unlike the other
            // *_updated_at fields above: scheduledTime is legitimately nil far more often
            // than the other fields are, and a push with a stale/nil local
            // scheduledTimeUpdatedAt must never win an LWW race against a real
            // server-side scheduled time by claiming "updated now" (SPRD-312).
            "scheduled_time_updated_at": SyncDateFormatting.formatTimestamp(scheduledTimeUpdatedAt ?? createdDate),
            "list_updated_at": SyncDateFormatting.formatTimestamp(listUpdatedAt ?? timestamp)
        ]
        return try? JSONSerialization.data(
            withJSONObject: record.compactMapValues { $0 ?? NSNull() }
        )
    }
}
