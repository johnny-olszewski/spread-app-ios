import Foundation

/// A bidirectional `SpreadDataModelKey ⇄ entity ID` index, updated incrementally per
/// mutation rather than recomputed wholesale.
///
/// One instance covers one entity kind (tasks or notes) — separate instances avoid mixing
/// buckets across kinds, even though `UUID` collision between a task and a note is not a
/// real-world concern. Forward lookups (`entityIDs(for:)`) answer "what's shown on this
/// spread surface" in O(1) bucket access; reverse lookups (`keys(for:)`) are needed to know
/// which bucket memberships to drop before adding the new ones when an entity's assignments
/// change. There is no separate "full rebuild" code path — cold load calls `update` once per
/// entity, which is the same incremental primitive every later mutation uses.
struct SpreadKeyIndex {
    private var entityIDsByKey: [SpreadDataModelKey: Set<UUID>] = [:]
    private var keysByEntityID: [UUID: Set<SpreadDataModelKey>] = [:]

    init() {}

    /// All entity IDs currently indexed under the given key. O(1) bucket access.
    func entityIDs(for key: SpreadDataModelKey) -> Set<UUID> {
        entityIDsByKey[key] ?? []
    }

    /// All keys the given entity is currently indexed under.
    func keys(for entityID: UUID) -> Set<SpreadDataModelKey> {
        keysByEntityID[entityID] ?? []
    }

    /// Updates one entity's bucket memberships to exactly `newKeys`, touching only the
    /// keys that actually changed (removed from stale buckets, added to new ones).
    ///
    /// Pass an empty set to fully remove the entity from the index (equivalent to
    /// `remove(entityID:)`).
    mutating func update(entityID: UUID, keys newKeys: Set<SpreadDataModelKey>) {
        let oldKeys = keysByEntityID[entityID] ?? []
        guard oldKeys != newKeys else { return }

        for key in oldKeys.subtracting(newKeys) {
            entityIDsByKey[key]?.remove(entityID)
            if entityIDsByKey[key]?.isEmpty == true {
                entityIDsByKey[key] = nil
            }
        }
        for key in newKeys.subtracting(oldKeys) {
            entityIDsByKey[key, default: []].insert(entityID)
        }

        if newKeys.isEmpty {
            keysByEntityID[entityID] = nil
        } else {
            keysByEntityID[entityID] = newKeys
        }
    }

    /// Removes the entity from every bucket it currently belongs to.
    mutating func remove(entityID: UUID) {
        update(entityID: entityID, keys: [])
    }
}
