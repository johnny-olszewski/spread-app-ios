import Foundation

/// Pairs a task with its pre-mutation change descriptor for a batched `saveAll` call.
struct TaskSaveRequest {
    /// The task to save, already mutated to its new state.
    let task: DataModel.Task
    /// The task's identity/assignments/tags as they existed before mutation.
    let change: EntityChange

    /// Creates a save request. Defaults to a brand-new task with no prior assignments or tags.
    init(task: DataModel.Task, change: EntityChange = EntityChange()) {
        self.task = task
        self.change = change
    }
}
