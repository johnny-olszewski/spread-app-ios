import Foundation

/// An open task whose due date has passed and that requires user review.
///
/// Produced by `OverdueEvaluator` and surfaced via `JournalManager.overdueTaskItems`.
/// The source key identifies where the task currently lives so the review UI
/// can offer the correct migration affordance.
struct OverdueTaskItem: Identifiable {
    /// The overdue open task.
    let task: DataModel.Task

    /// Identifies the spread (or Inbox) the task is currently assigned to.
    let sourceKey: TaskReviewSourceKey

    /// The task's unique identifier, used as the item identifier.
    var id: UUID { task.id }
}
