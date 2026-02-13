import Foundation

/// Assignment state for a task on a spread.
struct TaskAssignment: Codable, Hashable, AssignmentMatchable {
    /// The spread period for this assignment.
    var period: Period

    /// The spread date for this assignment.
    var date: Date

    /// The status of the task on this spread.
    var status: DataModel.Task.Status

    /// LWW timestamp for the `status` field.
    var statusUpdatedAt: Date?
}
