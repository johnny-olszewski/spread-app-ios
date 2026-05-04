import Foundation

/// Assignment state for a task on a spread.
struct TaskAssignment: Codable, Hashable, AssignmentMatchable {
    /// Stable logical identity for this assignment across sync and rebuilds.
    var id: UUID

    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// Explicit spread identity for direct multiday ownership.
    var spreadID: UUID?

    /// The status of the task on this spread.
    var status: DataModel.Task.Status

    /// LWW timestamp for the `status` field.
    var statusUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        period: Period,
        date: Date,
        spreadID: UUID? = nil,
        status: DataModel.Task.Status,
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
        status = try container.decode(DataModel.Task.Status.self, forKey: .status)
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
