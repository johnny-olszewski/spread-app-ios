import SwiftData

/// Protocol for wiping all local data.
///
/// Used by environment switching and launch-time mismatch handling
/// to ensure a clean slate before connecting to a different backend.
@MainActor
protocol StoreWiper: Sendable {
    /// Deletes all local data including SwiftData entities and sync state.
    func wipeAll() async throws
}

/// SwiftData implementation of StoreWiper.
///
/// Deletes all entities from all model types in the schema:
/// Spread, Task, Event, Note, Collection, SyncMutation, SyncCursor.
@MainActor
final class SwiftDataStoreWiper: StoreWiper {

    private let modelContainer: ModelContainer

    /// Creates a store wiper for the given container.
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func wipeAll() async throws {
        let context = modelContainer.mainContext

        // Delete all entity types
        try deleteAll(DataModel.Spread.self, from: context)
        try deleteAll(DataModel.Task.self, from: context)
        try deleteAll(DataModel.Event.self, from: context)
        try deleteAll(DataModel.Note.self, from: context)
        try deleteAll(DataModel.Collection.self, from: context)

        // Delete sync data
        try deleteAll(DataModel.SyncMutation.self, from: context)
        try deleteAll(DataModel.SyncCursor.self, from: context)

        try context.save()
    }

    /// Deletes all instances of a model type.
    private func deleteAll<T: PersistentModel>(_ type: T.Type, from context: ModelContext) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try context.fetch(descriptor)
        for item in items {
            context.delete(item)
        }
    }
}
