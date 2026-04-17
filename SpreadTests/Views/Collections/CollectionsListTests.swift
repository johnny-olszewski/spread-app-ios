import Foundation
import Testing
@testable import Spread

/// Tests for collections list CRUD behaviors.
///
/// Validates the repository interactions that back CollectionsListView:
/// empty state, create, delete, and sort order.
@Suite("Collections List Tests")
@MainActor
struct CollectionsListTests {

    // MARK: - Empty State

    /// When the repository has no collections,
    /// getCollections returns an empty array.
    @Test("Empty repository returns no collections")
    func emptyRepositoryReturnsNoCollections() async {
        let repo = InMemoryCollectionRepository()

        let collections = await repo.getCollections()

        #expect(collections.isEmpty)
    }

    // MARK: - Create

    /// When a new collection is created and saved,
    /// it appears in the repository's collection list.
    @Test("Creating a collection adds it to the repository")
    func creatingCollectionAddsToRepository() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "", content: "")

        try await repo.save(collection)
        let collections = await repo.getCollections()

        #expect(collections.count == 1)
        #expect(collections.first?.id == collection.id)
    }

    /// When a new collection is created with default parameters,
    /// it has empty title and content.
    @Test("New collection has empty title and content")
    func newCollectionHasEmptyTitleAndContent() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "", content: "")

        try await repo.save(collection)
        let collections = await repo.getCollections()

        #expect(collections.first?.title == "")
        #expect(collections.first?.content == "")
    }

    /// When multiple collections are created,
    /// they are returned sorted by modifiedDate descending (newest first).
    @Test("Collections sorted by modified date descending")
    func collectionsSortedByModifiedDateDescending() async throws {
        let repo = InMemoryCollectionRepository()
        let older = DataModel.Collection(
            title: "Older",
            content: "",
            modifiedDate: Date(timeIntervalSince1970: 1000)
        )
        let newer = DataModel.Collection(
            title: "Newer",
            content: "",
            modifiedDate: Date(timeIntervalSince1970: 2000)
        )

        try await repo.save(older)
        try await repo.save(newer)
        let collections = await repo.getCollections()

        #expect(collections.count == 2)
        #expect(collections[0].id == newer.id)
        #expect(collections[1].id == older.id)
    }

    // MARK: - Delete

    /// When a collection is deleted,
    /// it no longer appears in the repository's collection list.
    @Test("Deleting a collection removes it from the repository")
    func deletingCollectionRemovesFromRepository() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "To Delete", content: "")

        try await repo.save(collection)
        #expect(await repo.getCollections().count == 1)

        try await repo.delete(collection)
        let collections = await repo.getCollections()

        #expect(collections.isEmpty)
    }

    /// When one of multiple collections is deleted,
    /// only that collection is removed and others remain.
    @Test("Deleting one collection preserves others")
    func deletingOneCollectionPreservesOthers() async throws {
        let repo = InMemoryCollectionRepository()
        let keep = DataModel.Collection(title: "Keep", content: "")
        let remove = DataModel.Collection(title: "Remove", content: "")

        try await repo.save(keep)
        try await repo.save(remove)
        #expect(await repo.getCollections().count == 2)

        try await repo.delete(remove)
        let collections = await repo.getCollections()

        #expect(collections.count == 1)
        #expect(collections.first?.id == keep.id)
    }

    // MARK: - Content Preview

    /// When a collection has content,
    /// the content is preserved and accessible for preview display.
    @Test("Collection preserves content for preview")
    func collectionPreservesContentForPreview() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(
            title: "My Collection",
            content: "Line 1\nLine 2\nLine 3"
        )

        try await repo.save(collection)
        let collections = await repo.getCollections()

        #expect(collections.first?.content == "Line 1\nLine 2\nLine 3")
    }
}
