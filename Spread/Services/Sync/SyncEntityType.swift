/// Identifies a syncable entity type and its server-side table/RPC mapping.
///
/// Entity types define the push ordering (parents before children) and
/// map to the corresponding merge RPC function on the server.
enum SyncEntityType: String, CaseIterable, Codable, Sendable {
    case settings = "settings"
    case spread = "spreads"
    case entry = "entries"
    case collection = "collections"
    case list = "lists"
    case tag = "tags"
    case assignment = "assignments"
    case entryTag = "entry_tags"

    /// The merge RPC function name on the server.
    var mergeRPCName: String {
        switch self {
        case .settings: "merge_settings"
        case .spread: "merge_spread"
        case .entry: "merge_entry"
        case .collection: "merge_collection"
        case .list: "merge_list"
        case .tag: "merge_tag"
        case .assignment: "merge_assignment"
        case .entryTag: "merge_entry_tag"
        }
    }

    /// Push/pull ordering priority (lower = pushed first).
    ///
    /// Settings and spreads go first (no dependencies). Lists and tags come
    /// next because entries hold FK references to them. Entries and collections
    /// follow. Join rows and assignments come last.
    var syncOrder: Int {
        switch self {
        case .settings, .spread: 0
        case .list, .tag: 1
        case .entry, .collection: 2
        case .assignment, .entryTag: 3
        }
    }

    /// Whether this entity type supports the server-side `revision` column used for incremental pull.
    ///
    /// `entry_tags` uses a compound PK and does not have a `revision`
    /// column — it is push-only until pull is implemented for it.
    var supportsRevisionPull: Bool {
        switch self {
        case .entryTag: false
        default: true
        }
    }

    /// The batch merge RPC function name on the server, accepting a jsonb array of rows.
    var mergeBatchRPCName: String {
        switch self {
        case .settings: "merge_settings_batch"
        case .spread: "merge_spread_batch"
        case .entry: "merge_entry_batch"
        case .collection: "merge_collection_batch"
        case .list: "merge_list_batch"
        case .tag: "merge_tag_batch"
        case .assignment: "merge_assignment_batch"
        case .entryTag: "merge_entry_tag_batch"
        }
    }

    /// All entity types ordered for push/pull (parents first).
    static var ordered: [SyncEntityType] {
        allCases.sorted { $0.syncOrder < $1.syncOrder }
    }
}
