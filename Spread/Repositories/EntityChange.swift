import Foundation

/// Describes an assignable entity's assignments/tags/identity immediately before an
/// in-place mutation.
///
/// Callers hold this state one statement before mutating a task or note, then pass it
/// into a change-aware repository's `save` so the repository can diff for the sync
/// outbox using values already in memory instead of re-fetching prior state from disk.
struct EntityChange<Assignment> {
    /// `true` when the entity has never been persisted before; `false` for an update.
    let isNew: Bool
    /// The entity's assignments as they existed before the caller's mutation.
    let previousAssignments: [Assignment]
    /// The entity's tag IDs as they existed before the caller's mutation.
    let previousTagIDs: [UUID]

    /// Creates a change descriptor. Defaults describe a brand-new entity with no prior
    /// assignments or tags.
    init(isNew: Bool = true, previousAssignments: [Assignment] = [], previousTagIDs: [UUID] = []) {
        self.isNew = isNew
        self.previousAssignments = previousAssignments
        self.previousTagIDs = previousTagIDs
    }
}
