import Testing
import Foundation
import SwiftData
@testable import Spread

/// Tests for collection repository CRUD operations.
///
/// Validates both InMemoryCollectionRepository and SwiftDataCollectionRepository
/// implementations against the CollectionRepository protocol contract.
@Suite("Collection Repository Tests")
struct CollectionRepositoryTests {

    // MARK: - InMemory CRUD

    /// Conditions: Save a collection to an empty InMemory repository.
    /// Expected: getCollections returns the saved collection with correct fields.
    @Test @MainActor func testInMemorySaveAndRetrieve() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(
            title: "Books to Read",
            content: "- The Pragmatic Programmer",
            createdDate: .now,
            modifiedDate: .now
        )

        try await repo.save(collection)
        let result = await repo.getCollections()

        #expect(result.count == 1)
        #expect(result[0].id == collection.id)
        #expect(result[0].title == "Books to Read")
        #expect(result[0].content == "- The Pragmatic Programmer")
    }

    /// Conditions: Save multiple collections with different modifiedDates.
    /// Expected: getCollections returns them sorted by modifiedDate descending.
    @Test @MainActor func testInMemorySortsByModifiedDateDescending() async throws {
        let repo = InMemoryCollectionRepository()
        let now = Date.now
        let older = DataModel.Collection(
            title: "Older",
            content: "old",
            createdDate: now.addingTimeInterval(-200),
            modifiedDate: now.addingTimeInterval(-100)
        )
        let newer = DataModel.Collection(
            title: "Newer",
            content: "new",
            createdDate: now.addingTimeInterval(-100),
            modifiedDate: now
        )

        try await repo.save(older)
        try await repo.save(newer)
        let result = await repo.getCollections()

        #expect(result.count == 2)
        #expect(result[0].title == "Newer")
        #expect(result[1].title == "Older")
    }

    /// Conditions: Save a collection, then update its title and content.
    /// Expected: getCollections returns the updated version.
    @Test @MainActor func testInMemoryUpdate() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(
            title: "Original",
            content: "original content"
        )

        try await repo.save(collection)
        collection.title = "Updated"
        collection.content = "updated content"
        try await repo.save(collection)

        let result = await repo.getCollections()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated")
        #expect(result[0].content == "updated content")
    }

    /// Conditions: Save a collection, then delete it.
    /// Expected: getCollections returns an empty array.
    @Test @MainActor func testInMemoryDelete() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "To Delete", content: "gone")

        try await repo.save(collection)
        try await repo.delete(collection)

        let result = await repo.getCollections()
        #expect(result.isEmpty)
    }

    /// Conditions: Create InMemory repository with pre-populated collections.
    /// Expected: getCollections returns the pre-populated collections.
    @Test @MainActor func testInMemoryPrePopulated() async {
        let collections = [
            DataModel.Collection(title: "A", content: "a", modifiedDate: .now),
            DataModel.Collection(title: "B", content: "b", modifiedDate: .now.addingTimeInterval(-50))
        ]
        let repo = InMemoryCollectionRepository(collections: collections)

        let result = await repo.getCollections()
        #expect(result.count == 2)
        #expect(result[0].title == "A")
        #expect(result[1].title == "B")
    }

    /// Conditions: Empty InMemory repository.
    /// Expected: getCollections returns an empty array.
    @Test @MainActor func testInMemoryEmptyRepository() async {
        let repo = InMemoryCollectionRepository()
        let result = await repo.getCollections()
        #expect(result.isEmpty)
    }

    // MARK: - SwiftData CRUD

    /// Conditions: Save a collection to SwiftData repository.
    /// Expected: getCollections returns the saved collection with correct fields.
    @Test @MainActor func testSwiftDataSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let collection = DataModel.Collection(
            title: "Goals",
            content: "- Ship v1\n- Read 24 books",
            createdDate: .now,
            modifiedDate: .now
        )

        try await repo.save(collection)
        let result = await repo.getCollections()

        #expect(result.count == 1)
        #expect(result[0].title == "Goals")
        #expect(result[0].content == "- Ship v1\n- Read 24 books")
    }

    /// Conditions: Save multiple collections with different modifiedDates to SwiftData.
    /// Expected: getCollections returns them sorted by modifiedDate descending.
    @Test @MainActor func testSwiftDataSortsByModifiedDateDescending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let now = Date.now

        let older = DataModel.Collection(
            title: "Older",
            content: "old",
            createdDate: now.addingTimeInterval(-200),
            modifiedDate: now.addingTimeInterval(-100)
        )
        let newer = DataModel.Collection(
            title: "Newer",
            content: "new",
            createdDate: now.addingTimeInterval(-100),
            modifiedDate: now
        )

        try await repo.save(older)
        try await repo.save(newer)
        let result = await repo.getCollections()

        #expect(result.count == 2)
        #expect(result[0].title == "Newer")
        #expect(result[1].title == "Older")
    }

    /// Conditions: Save a collection, then delete it via SwiftData.
    /// Expected: getCollections returns an empty array.
    @Test @MainActor func testSwiftDataDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let collection = DataModel.Collection(title: "To Delete", content: "gone")

        try await repo.save(collection)
        try await repo.delete(collection)

        let result = await repo.getCollections()
        #expect(result.isEmpty)
    }

    /// Conditions: Save a collection to SwiftData repository.
    /// Expected: A SyncMutation is enqueued in the outbox.
    @Test @MainActor func testSwiftDataSaveEnqueuesSyncMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let collection = DataModel.Collection(title: "Synced", content: "data")

        try await repo.save(collection)

        let mutations = try container.mainContext.fetch(
            FetchDescriptor<DataModel.SyncMutation>()
        )
        #expect(mutations.count == 1)
        #expect(mutations[0].entityType == "collections")
        #expect(mutations[0].operation == "create")
        #expect(mutations[0].entityId == collection.id)
    }

    /// Conditions: Save an existing collection again (update).
    /// Expected: The mutation operation is "update".
    @Test @MainActor func testSwiftDataUpdateEnqueuesUpdateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let collection = DataModel.Collection(title: "Original", content: "v1")

        try await repo.save(collection)
        collection.title = "Updated"
        collection.content = "v2"
        try await repo.save(collection)

        let mutations = try container.mainContext.fetch(
            FetchDescriptor<DataModel.SyncMutation>()
        )
        #expect(mutations.count == 2)
        let updateMutation = mutations.first { $0.operation == "update" }
        #expect(updateMutation != nil)
    }

    /// Conditions: Delete a collection from SwiftData.
    /// Expected: A delete SyncMutation is enqueued.
    @Test @MainActor func testSwiftDataDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let collection = DataModel.Collection(title: "To Delete", content: "")

        try await repo.save(collection)
        try await repo.delete(collection)

        let mutations = try container.mainContext.fetch(
            FetchDescriptor<DataModel.SyncMutation>()
        )
        let deleteMutation = mutations.first { $0.operation == "delete" }
        #expect(deleteMutation != nil)
        #expect(deleteMutation?.entityId == collection.id)
    }

    // MARK: - Content

    /// Conditions: Save a collection with empty content.
    /// Expected: Content is stored as empty string.
    @Test @MainActor func testCollectionEmptyContent() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "Empty Page")

        try await repo.save(collection)
        let result = await repo.getCollections()

        #expect(result[0].content == "")
    }

    /// Conditions: Save a collection with large content.
    /// Expected: Content is stored without truncation.
    @Test @MainActor func testCollectionLargeContent() async throws {
        let repo = InMemoryCollectionRepository()
        let largeContent = String(repeating: "Line of text\n", count: 10_000)
        let collection = DataModel.Collection(
            title: "Large Collection",
            content: largeContent
        )

        try await repo.save(collection)
        let result = await repo.getCollections()

        #expect(result[0].content == largeContent)
    }

    // MARK: - Mock Repository

    /// Conditions: Create MockCollectionRepository with default sample data.
    /// Expected: Returns non-empty collections with content.
    @Test @MainActor func testMockRepositoryHasSampleData() async {
        let repo = MockCollectionRepository()
        let result = await repo.getCollections()

        #expect(!result.isEmpty)
        #expect(result.allSatisfy { !$0.title.isEmpty })
        #expect(result.allSatisfy { !$0.content.isEmpty })
    }
}
