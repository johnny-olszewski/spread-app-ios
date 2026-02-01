/// The type of change recorded in a sync mutation.
enum SyncOperation: String, Codable, Sendable {
    /// A new entity was created locally.
    case create

    /// An existing entity was updated locally.
    case update

    /// An entity was soft-deleted locally.
    case delete
}
