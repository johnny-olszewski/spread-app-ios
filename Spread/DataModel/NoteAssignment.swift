import struct Foundation.Date

/// Assignment state for a note on a spread.
struct NoteAssignment: Codable, Hashable, AssignmentMatchable {
    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// The status of the note on this spread.
    var status: DataModel.Note.Status
}
