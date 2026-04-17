/// Errors that can occur during task mutation operations.
enum TaskMutationError: Error, Equatable {
    /// The caller attempted to set a task's status directly to `.migrated`.
    ///
    /// The `.migrated` status is managed exclusively by migration workflows.
    /// Views must not expose this as a user-selectable status.
    case manualMigratedStatusNotAllowed
}
