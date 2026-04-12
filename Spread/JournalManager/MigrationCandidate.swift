import Foundation

/// A task that is eligible to be migrated to a destination spread.
///
/// Produced by `MigrationPlanner` and surfaced to views so they can present
/// actionable migration affordances. Each candidate pairs a task with the
/// source it currently lives on (or Inbox) and the single best destination spread.
struct MigrationCandidate: Identifiable {
    /// The task eligible for migration.
    let task: DataModel.Task

    /// Identifies where the task currently lives — Inbox or a specific spread.
    let sourceKey: TaskReviewSourceKey

    /// The spread the task is currently assigned to, if any.
    ///
    /// `nil` when the source is Inbox (the task has no matching spread assignment).
    let sourceSpread: DataModel.Spread?

    /// The target spread this task should be migrated to.
    let destination: DataModel.Spread

    /// A stable composite identifier combining task, source, and destination.
    var id: String {
        "\(task.id.uuidString)-\(sourceKey.id)-\(destination.id.uuidString)"
    }
}
