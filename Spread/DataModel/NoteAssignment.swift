import Foundation

/// Assignment state for a note on a spread.
struct NoteAssignment: Codable, Hashable, AssignmentMatchable {
    /// Stable logical identity for this assignment across sync and rebuilds.
    var id: UUID

    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// The status of the note on this spread.
    var status: DataModel.Note.Status

    /// LWW timestamp for the `status` field.
    var statusUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        period: Period,
        date: Date,
        status: DataModel.Note.Status,
        statusUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.period = period
        self.date = date
        self.status = status
        self.statusUpdatedAt = statusUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case period
        case date
        case status
        case statusUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        period = try container.decode(Period.self, forKey: .period)
        date = try container.decode(Date.self, forKey: .date)
        status = try container.decode(DataModel.Note.Status.self, forKey: .status)
        statusUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .statusUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(period, forKey: .period)
        try container.encode(date, forKey: .date)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(statusUpdatedAt, forKey: .statusUpdatedAt)
    }
}
