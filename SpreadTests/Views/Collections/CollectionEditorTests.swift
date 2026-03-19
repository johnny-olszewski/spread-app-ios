import Foundation
import Testing
@testable import Spread

/// Integration tests for collection editor persistence.
///
/// Validates that edits to collection title and content persist
/// through the repository and that modifiedDate is updated.
@Suite("Collection Editor Persistence Tests")
@MainActor
struct CollectionEditorTests {

    // MARK: - Title Persistence

    /// When the collection title is changed and saved,
    /// the updated title persists in the repository.
    @Test("Editing title persists to repository")
    func editingTitlePersistsToRepository() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "Original", content: "")
        try await repo.save(collection)

        collection.title = "Updated Title"
        try await repo.save(collection)

        let collections = await repo.getCollections()
        #expect(collections.count == 1)
        #expect(collections.first?.title == "Updated Title")
    }

    // MARK: - Content Persistence

    /// When the collection content is changed and saved,
    /// the updated content persists in the repository.
    @Test("Editing content persists to repository")
    func editingContentPersistsToRepository() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "My List", content: "")
        try await repo.save(collection)

        collection.content = "Line 1\nLine 2\nLine 3"
        try await repo.save(collection)

        let collections = await repo.getCollections()
        #expect(collections.first?.content == "Line 1\nLine 2\nLine 3")
    }

    // MARK: - ModifiedDate Update

    /// When a collection is edited and saved,
    /// the modifiedDate is updated to reflect the save time.
    @Test("Saving updates modifiedDate")
    func savingUpdatesModifiedDate() async throws {
        let repo = InMemoryCollectionRepository()
        let pastDate = Date(timeIntervalSince1970: 1000)
        let collection = DataModel.Collection(
            title: "Test",
            content: "",
            modifiedDate: pastDate
        )
        try await repo.save(collection)

        // Simulate what the editor does on save
        collection.title = "Updated"
        collection.modifiedDate = .now
        try await repo.save(collection)

        let collections = await repo.getCollections()
        let saved = collections.first
        #expect(saved != nil)
        #expect(saved!.modifiedDate > pastDate)
    }

    // MARK: - Concurrent Title and Content

    /// When both title and content are changed and saved together,
    /// both changes persist in a single save operation.
    @Test("Editing title and content together persists both")
    func editingTitleAndContentTogetherPersistsBoth() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "Old Title", content: "Old Content")
        try await repo.save(collection)

        collection.title = "New Title"
        collection.content = "New Content"
        collection.modifiedDate = .now
        try await repo.save(collection)

        let collections = await repo.getCollections()
        let saved = collections.first
        #expect(saved?.title == "New Title")
        #expect(saved?.content == "New Content")
    }

    // MARK: - Identity Preservation

    /// When a collection is edited and saved,
    /// the collection's id remains unchanged.
    @Test("Editing preserves collection id")
    func editingPreservesCollectionId() async throws {
        let repo = InMemoryCollectionRepository()
        let collection = DataModel.Collection(title: "Test", content: "")
        let originalId = collection.id
        try await repo.save(collection)

        collection.title = "Changed"
        collection.modifiedDate = .now
        try await repo.save(collection)

        let collections = await repo.getCollections()
        #expect(collections.first?.id == originalId)
    }

    // MARK: - Sort Order After Edit

    /// When a collection's modifiedDate is updated via edit,
    /// it moves to the top of the sorted list.
    @Test("Edited collection moves to top of list")
    func editedCollectionMovesToTopOfList() async throws {
        let repo = InMemoryCollectionRepository()
        let older = DataModel.Collection(
            title: "First",
            content: "",
            modifiedDate: Date(timeIntervalSince1970: 1000)
        )
        let newer = DataModel.Collection(
            title: "Second",
            content: "",
            modifiedDate: Date(timeIntervalSince1970: 2000)
        )
        try await repo.save(older)
        try await repo.save(newer)

        // Edit the older collection, updating its modifiedDate
        older.title = "First (edited)"
        older.modifiedDate = Date(timeIntervalSince1970: 3000)
        try await repo.save(older)

        let collections = await repo.getCollections()
        #expect(collections[0].id == older.id)
        #expect(collections[1].id == newer.id)
    }
}
