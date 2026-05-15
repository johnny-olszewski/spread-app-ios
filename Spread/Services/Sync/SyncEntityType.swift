/// Identifies a syncable entity type and its server-side table/RPC mapping.
///
/// Entity types define the push ordering (parents before children) and
/// map to the corresponding merge RPC function on the server.
enum SyncEntityType: String, CaseIterable, Codable, Sendable {
    case settings = "settings"
    case spread = "spreads"
    case task = "tasks"
    case note = "notes"
    case collection = "collections"
    case list = "lists"
    case tag = "tags"
    case taskAssignment = "task_assignments"
    case noteAssignment = "note_assignments"
    case taskTag = "task_tags"
    case noteTag = "note_tags"

    /// The merge RPC function name on the server.
    var mergeRPCName: String {
        switch self {
        case .settings: "merge_settings"
        case .spread: "merge_spread"
        case .task: "merge_task"
        case .note: "merge_note"
        case .collection: "merge_collection"
        case .list: "merge_list"
        case .tag: "merge_tag"
        case .taskAssignment: "merge_task_assignment"
        case .noteAssignment: "merge_note_assignment"
        case .taskTag: "merge_task_tag"
        case .noteTag: "merge_note_tag"
        }
    }

    /// Push/pull ordering priority (lower = pushed first).
    ///
    /// Settings and spreads go first (no dependencies). Lists and tags come
    /// next because tasks and notes hold FK references to them. Tasks, notes,
    /// and collections follow. Join rows and assignments come last.
    var syncOrder: Int {
        switch self {
        case .settings, .spread: 0
        case .list, .tag: 1
        case .task, .note, .collection: 2
        case .taskAssignment, .noteAssignment, .taskTag, .noteTag: 3
        }
    }

    /// Whether this entity type supports the server-side `revision` column used for incremental pull.
    ///
    /// Join tables (`task_tags`, `note_tags`) use a compound PK and do not have a `revision`
    /// column — they are push-only until pull is implemented for them.
    var supportsRevisionPull: Bool {
        switch self {
        case .taskTag, .noteTag: false
        default: true
        }
    }

    /// All entity types ordered for push/pull (parents first).
    static var ordered: [SyncEntityType] {
        allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
}
