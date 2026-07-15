import Foundation

/// The shared item shape for task review surfaces — the overdue, in-flight, and inbox
/// segments of the review panel.
///
/// Pairs a task with the `TaskReviewSourceKey` identifying where it currently lives, so the
/// review UI can offer the correct migration affordance regardless of which segment produced
/// the item. Produced by `JournalRuleEngine.overdueTaskItems`/`.inFlightTaskItems` and
/// surfaced via `JournalManager.overdueTaskItems`/`.inFlightTaskItems` [SPRD-317].
struct TaskReviewItem: Identifiable {
    /// The task being reviewed.
    let task: DataModel.Task

    /// Identifies the spread (or Inbox) the task is currently assigned to.
    let sourceKey: TaskReviewSourceKey

    /// The task's unique identifier, used as the item identifier.
    var id: UUID { task.id }
}
