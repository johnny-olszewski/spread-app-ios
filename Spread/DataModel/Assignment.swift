import Foundation

/// Assignment state for an entry (task or note) on a spread.
///
/// `Assignment` and `Assignment` were previously separate, byte-identical types
/// with no behavioral divergence — collapsed into this single type since the protocol
/// (`AssignmentMatchable`) and associated type (`AssignableEntry.AssignmentType`) that
/// existed solely to abstract over them were pure indirection with no second shape ever
/// needing to differ. `SyncEntityType.taskAssignment`/`.noteAssignment` remain separate —
/// that distinction is real server-side structure (separate Postgres tables), unrelated to
/// this Swift value type's shape.
struct Assignment: Codable, Hashable {
    /// Stable logical identity for this assignment across sync and rebuilds.
    var id: UUID

    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// Explicit spread identity for direct multiday ownership.
    var spreadID: UUID?

    /// The status of the entry on this spread.
    var status: EntryStatus

    /// LWW timestamp for the `status` field.
    var statusUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        period: Period,
        date: Date,
        spreadID: UUID? = nil,
        status: EntryStatus,
        statusUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.period = period
        self.date = date
        self.spreadID = spreadID
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case period
        case date
        case spreadID
        case status
        case statusUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        period = try container.decode(Period.self, forKey: .period)
        date = try container.decode(Date.self, forKey: .date)
        spreadID = try container.decodeIfPresent(UUID.self, forKey: .spreadID)
        status = try container.decode(EntryStatus.self, forKey: .status)
        statusUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .statusUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(period, forKey: .period)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(spreadID, forKey: .spreadID)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(statusUpdatedAt, forKey: .statusUpdatedAt)
    }
}

extension Assignment {
    /// `true` when this assignment represents migrated (no longer live) history.
    var isMigrated: Bool { status == .migrated }

    /// Determines whether this assignment matches a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - spreadID: The explicit spread identity, if available.
    ///   - calendar: The calendar to use for date normalization.
    /// - Returns: `true` if the assignment matches the spread.
    func matches(period: Period, date: Date, spreadID: UUID? = nil, calendar: Calendar) -> Bool {
        if let spreadID, let assignmentSpreadID = self.spreadID {
            return assignmentSpreadID == spreadID
        }

        guard self.period == period else { return false }
        let normalizedSelf = period.normalizeDate(self.date, calendar: calendar)
        let normalizedOther = period.normalizeDate(date, calendar: calendar)
        return normalizedSelf == normalizedOther
    }

    func matches(spread: DataModel.Spread, calendar: Calendar) -> Bool {
        matches(
            period: spread.period,
            date: spread.date,
            spreadID: spread.id,
            calendar: calendar
        )
    }
}
