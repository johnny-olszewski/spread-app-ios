import Foundation

/// A dictionary-keyed canonical store for one entity type, providing O(1) upsert/remove/lookup.
///
/// Replaces the flat-array storage (`JournalManager.tasks`/`.notes`/`.events`) that requires
/// a linear scan (`firstIndex(where:)`, `removeAll(where:)`) for single-entity mutations.
///
/// Keyed via an explicit `id` key path rather than an `Identifiable` constraint: `Entry`
/// conformers (`Task`/`Note`/`Event`) already have `id: UUID`, but `DataModel.Spread` can't
/// be conformed to `Identifiable` directly — confirmed empirically, conforming a `@Model`
/// class to a new protocol that isn't reached through an existing intermediate protocol
/// breaks the macro's `PersistentModel`/`Hashable` synthesis under this project's strict-
/// concurrency build settings, the same issue documented on `AssignableEntry` in
/// `Entry.swift`. A key path sidesteps this entirely — no new conformance needed on any type.
struct EntityStore<E> {
    private let idKeyPath: KeyPath<E, UUID>
    private var entitiesByID: [UUID: E] = [:]

    init(idKeyPath: KeyPath<E, UUID>) {
        self.idKeyPath = idKeyPath
    }

    init(_ entities: [E], idKeyPath: KeyPath<E, UUID>) {
        self.idKeyPath = idKeyPath
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0[keyPath: idKeyPath], $0) })
    }

    /// All entities in the store, in unspecified order.
    var values: [E] {
        Array(entitiesByID.values)
    }

    /// The number of entities currently stored.
    var count: Int {
        entitiesByID.count
    }

    /// Looks up a single entity by identifier. O(1).
    subscript(id: UUID) -> E? {
        entitiesByID[id]
    }

    /// Inserts a new entity or replaces an existing one with the same identifier. O(1).
    @discardableResult
    mutating func upsert(_ entity: E) -> E? {
        entitiesByID.updateValue(entity, forKey: entity[keyPath: idKeyPath])
    }

    /// Removes the entity with the given identifier, if present. O(1).
    @discardableResult
    mutating func remove(id: UUID) -> E? {
        entitiesByID.removeValue(forKey: id)
    }

    /// Replaces the entire store's contents, e.g. for cold load.
    mutating func replaceAll(_ entities: [E]) {
        entitiesByID = Dictionary(uniqueKeysWithValues: entities.map { ($0[keyPath: idKeyPath], $0) })
    }
}
