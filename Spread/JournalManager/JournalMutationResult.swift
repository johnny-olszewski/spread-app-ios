import Foundation

enum JournalMutationScope: Equatable, Sendable {
    case spreadKeys(Set<SpreadDataModelKey>)
    case structural
}

enum JournalMutationKind: Equatable, Sendable {
    case taskChanged(id: UUID)
    case noteChanged(id: UUID)
    case spreadChanged(key: SpreadDataModelKey)
    case structural
}

struct JournalMutationResult: Equatable, Sendable {
    let kind: JournalMutationKind
    let scope: JournalMutationScope

    static func structural() -> JournalMutationResult {
        JournalMutationResult(kind: .structural, scope: .structural)
    }
}

struct TaskListMutationResult: Sendable {
    let task: DataModel.Task
    let tasks: [DataModel.Task]
    let mutation: JournalMutationResult
}

struct NoteListMutationResult: Sendable {
    let note: DataModel.Note
    let notes: [DataModel.Note]
    let mutation: JournalMutationResult
}

struct SpreadListMutationResult: Sendable {
    let spreads: [DataModel.Spread]
    let mutation: JournalMutationResult
}
