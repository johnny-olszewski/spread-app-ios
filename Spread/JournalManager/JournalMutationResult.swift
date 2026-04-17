import Foundation

/// Describes how much of the derived journal state must be refreshed after a mutation.
///
/// `.spreadKeys` is the targeted fast path used for ordinary edits and migrations.
/// `.structural` is the conservative fallback for broad invalidation such as reloads
/// and spread deletion.
enum JournalMutationScope: Equatable, Sendable {
    case spreadKeys(Set<SpreadDataModelKey>)
    case structural
}

/// Domain-level classification for a journal mutation.
///
/// These values intentionally stay domain-scoped so mutation services do not leak
/// UI refresh concerns into the business-logic layer.
enum JournalMutationKind: Equatable, Sendable {
    case taskChanged(id: UUID)
    case noteChanged(id: UUID)
    case spreadChanged(key: SpreadDataModelKey)
    case structural
}

/// Result metadata returned by mutation workflows.
///
/// The mutation kind identifies what changed, while the scope tells `JournalManager`
/// how narrowly it can patch the derived `JournalDataModel`.
struct JournalMutationResult: Equatable, Sendable {
    let kind: JournalMutationKind
    let scope: JournalMutationScope

    static func structural() -> JournalMutationResult {
        JournalMutationResult(kind: .structural, scope: .structural)
    }
}

/// Result of a task mutation that persists one task and returns the refreshed task list.
struct TaskListMutationResult: Sendable {
    let task: DataModel.Task
    let tasks: [DataModel.Task]
    let mutation: JournalMutationResult
}

/// Result of a note mutation that persists one note and returns the refreshed note list.
struct NoteListMutationResult: Sendable {
    let note: DataModel.Note
    let notes: [DataModel.Note]
    let mutation: JournalMutationResult
}

/// Result of a spread mutation that returns the refreshed spread list.
struct SpreadListMutationResult: Sendable {
    let spreads: [DataModel.Spread]
    let mutation: JournalMutationResult
}
