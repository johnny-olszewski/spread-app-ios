/// Identifies a syncable entity type and its server-side table/RPC mapping.
///
/// Entity types define the push ordering (parents before children) and
/// map to the corresponding merge RPC function on the server.
enum SyncEntityType: String, CaseIterable, Codable, Sendable {
    case spread = "spreads"
    case task = "tasks"
    case note = "notes"
    case collection = "collections"
    case taskAssignment = "task_assignments"
    case noteAssignment = "note_assignments"

    /// The merge RPC function name on the server.
    var mergeRPCName: String {
        switch self {
        case .spread: "merge_spread"
        case .task: "merge_task"
        case .note: "merge_note"
        case .collection: "merge_collection"
        case .taskAssignment: "merge_task_assignment"
        case .noteAssignment: "merge_note_assignment"
        }
    }

    /// Push/pull ordering priority (lower = pushed first).
    ///
    /// Parents must be pushed before children to satisfy foreign key constraints.
    /// Spreads go first, then standalone entities, then assignments.
    var syncOrder: Int {
        switch self {
        case .spread: 0
        case .task, .note, .collection: 1
        case .taskAssignment, .noteAssignment: 2
        }
    }

    /// All entity types ordered for push/pull (parents first).
    static var ordered: [SyncEntityType] {
        allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
}
