import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `ModelContext.enqueueCoalescedSyncMutation`, covering SPRD-253's "Outbox Mutation
/// Coalescing" policy in isolation from any specific repository.
@MainActor
struct ModelContextSyncOutboxTests {

    private func recordData(_ value: String = "x") -> Data {
        Data(value.utf8)
    }

    private func fetchMutations(from container: ModelContainer) throws -> [DataModel.SyncMutation] {
        try container.mainContext.fetch(FetchDescriptor<DataModel.SyncMutation>())
    }

    /// Conditions: Three consecutive update mutations enqueued for the same entity.
    /// Expected: Exactly one outbox row exists, containing the final mutation's record data.
    @Test func testThreeConsecutiveUpdatesProduceOneRow() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let entityId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("first")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("second")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("third")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 1)
        #expect(mutations.first?.recordData == recordData("third"))
        #expect(mutations.first?.operation == SyncOperation.update.rawValue)
    }

    /// Conditions: A create mutation followed by one or more update mutations for the same entity.
    /// Expected: One outbox row, still `operation == .create` (never downgraded), with the latest data.
    @Test func testCreateFollowedByUpdatesStaysCreateWithLatestData() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let entityId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .create, recordData: recordData("created")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("updated")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 1)
        #expect(mutations.first?.operation == SyncOperation.create.rawValue)
        #expect(mutations.first?.recordData == recordData("updated"))
    }

    /// Conditions: An update mutation followed by a delete mutation for the same entity.
    /// Expected: One outbox row with `operation == .delete` — the update is never pushed separately.
    @Test func testUpdateFollowedByDeleteProducesDeleteRow() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let entityId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("updated")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .delete, recordData: recordData("deleted")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 1)
        #expect(mutations.first?.operation == SyncOperation.delete.rawValue)
    }

    /// Conditions: A create mutation followed by a delete mutation for the same entity.
    /// Expected: One outbox row with `operation == .delete` — a delete always wins outright,
    /// even over a prior unsent create.
    @Test func testCreateFollowedByDeleteProducesDeleteRow() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let entityId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .create, recordData: recordData("created")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .delete, recordData: recordData("deleted")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 1)
        #expect(mutations.first?.operation == SyncOperation.delete.rawValue)
    }

    /// Conditions: Mutations enqueued for two different entities.
    /// Expected: Each entity gets its own outbox row — they are not coalesced together.
    @Test func testMutationsForDifferentEntitiesProduceSeparateRows() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let firstId = UUID()
        let secondId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: firstId,
            operation: .create, recordData: recordData("first")
        )
        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: secondId,
            operation: .create, recordData: recordData("second")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 2)
        #expect(Set(mutations.map(\.entityId)) == [firstId, secondId])
    }

    /// Conditions: A mutation enqueued for an entity, the resulting row deleted (simulating a
    /// successful `SyncEngine.push()`), then a new mutation enqueued for the same entity.
    /// Expected: A fresh row is inserted rather than coalescing with the (now-gone) prior one.
    @Test func testMutationAfterPushedRowDeletionInsertsFreshRow() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let entityId = UUID()

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("first")
        )
        let pushedMutation = try fetchMutations(from: container).first!
        context.delete(pushedMutation)

        context.enqueueCoalescedSyncMutation(
            entityType: SyncEntityType.entry.rawValue, entityId: entityId,
            operation: .update, recordData: recordData("second")
        )

        let mutations = try fetchMutations(from: container)
        #expect(mutations.count == 1)
        #expect(mutations.first?.recordData == recordData("second"))
    }
}
