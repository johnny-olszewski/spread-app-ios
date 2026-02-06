import Foundation
import SwiftData
import Testing
@testable import Spread

@MainActor
struct StoreWiperTests {

    // MARK: - Wipe All Data

    /// Conditions: Store has spreads, tasks, and notes.
    /// Expected: All data is deleted after wipeAll().
    @Test func wipeAllDeletesAllEntities() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        // Insert test data
        let spread = DataModel.Spread(period: .day, date: .now, calendar: .current)
        let task = DataModel.Task(title: "Test Task")
        let note = DataModel.Note(title: "Test Note")
        context.insert(spread)
        context.insert(task)
        context.insert(note)
        try context.save()

        // Verify data exists
        let spreadsBefore = try context.fetchCount(FetchDescriptor<DataModel.Spread>())
        let tasksBefore = try context.fetchCount(FetchDescriptor<DataModel.Task>())
        let notesBefore = try context.fetchCount(FetchDescriptor<DataModel.Note>())
        #expect(spreadsBefore > 0)
        #expect(tasksBefore > 0)
        #expect(notesBefore > 0)

        // Wipe
        let wiper = SwiftDataStoreWiper(modelContainer: container)
        try await wiper.wipeAll()

        // Verify all data deleted
        let spreadsAfter = try context.fetchCount(FetchDescriptor<DataModel.Spread>())
        let tasksAfter = try context.fetchCount(FetchDescriptor<DataModel.Task>())
        let notesAfter = try context.fetchCount(FetchDescriptor<DataModel.Note>())
        #expect(spreadsAfter == 0)
        #expect(tasksAfter == 0)
        #expect(notesAfter == 0)
    }

    /// Conditions: Store has sync mutations and cursors.
    /// Expected: Sync data is also deleted after wipeAll().
    @Test func wipeAllDeletesSyncData() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        // Insert sync data
        let mutation = DataModel.SyncMutation(
            entityType: "tasks",
            entityId: UUID(),
            operation: "upsert",
            recordData: Data(),
            changedFields: []
        )
        let cursor = DataModel.SyncCursor(tableName: "tasks", lastRevision: 100)
        context.insert(mutation)
        context.insert(cursor)
        try context.save()

        // Verify data exists
        let mutationsBefore = try context.fetchCount(FetchDescriptor<DataModel.SyncMutation>())
        let cursorsBefore = try context.fetchCount(FetchDescriptor<DataModel.SyncCursor>())
        #expect(mutationsBefore > 0)
        #expect(cursorsBefore > 0)

        // Wipe
        let wiper = SwiftDataStoreWiper(modelContainer: container)
        try await wiper.wipeAll()

        // Verify sync data deleted
        let mutationsAfter = try context.fetchCount(FetchDescriptor<DataModel.SyncMutation>())
        let cursorsAfter = try context.fetchCount(FetchDescriptor<DataModel.SyncCursor>())
        #expect(mutationsAfter == 0)
        #expect(cursorsAfter == 0)
    }

    /// Conditions: Store is already empty.
    /// Expected: wipeAll() succeeds without error.
    @Test func wipeAllSucceedsOnEmptyStore() async throws {
        let container = try ModelContainerFactory.makeForTesting()
        let wiper = SwiftDataStoreWiper(modelContainer: container)

        // Should not throw
        try await wiper.wipeAll()

        // Verify still empty
        let context = container.mainContext
        let spreads = try context.fetchCount(FetchDescriptor<DataModel.Spread>())
        #expect(spreads == 0)
    }
}
