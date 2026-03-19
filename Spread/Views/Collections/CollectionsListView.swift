import SwiftUI

/// List view for browsing, creating, and deleting collections.
///
/// Displays all collections sorted by most recently modified. Provides
/// a toolbar button to create new collections, swipe-to-delete with
/// confirmation, and tapping a row opens the collection editor (SPRD-41).
struct CollectionsListView: View {

    // MARK: - Properties

    /// Repository for collection persistence.
    let collectionRepository: any CollectionRepository

    /// Optional sync engine to trigger sync after mutations.
    let syncEngine: SyncEngine?

    /// All collections loaded from the repository.
    @State private var collections: [DataModel.Collection] = []

    /// Whether the delete confirmation alert is presented.
    @State private var collectionToDelete: DataModel.Collection?

    /// Whether a create operation is in progress.
    @State private var isCreating = false

    // MARK: - Body

    var body: some View {
        Group {
            if collections.isEmpty {
                emptyState
            } else {
                collectionList
            }
        }
        .task {
            await loadCollections()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCollection()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(isCreating)
                .accessibilityLabel("Create Collection")
            }
        }
        .alert(
            "Delete Collection",
            isPresented: Binding(
                get: { collectionToDelete != nil },
                set: { if !$0 { collectionToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    deleteCollection(collection)
                }
            }
            Button("Cancel", role: .cancel) {
                collectionToDelete = nil
            }
        } message: {
            if let collection = collectionToDelete {
                Text("Are you sure you want to delete \"\(collection.title.isEmpty ? "Untitled" : collection.title)\"?")
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Collections", systemImage: "folder")
        } description: {
            Text("Tap + to create your first collection.")
        }
    }

    private var collectionList: some View {
        List {
            ForEach(collections, id: \.id) { collection in
                NavigationLink {
                    CollectionEditorView(
                        collection: collection,
                        collectionRepository: collectionRepository,
                        syncEngine: syncEngine,
                        onEdited: {
                            Task { await loadCollections() }
                        }
                    )
                } label: {
                    CollectionRow(collection: collection)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete", role: .destructive) {
                        collectionToDelete = collection
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func loadCollections() async {
        collections = await collectionRepository.getCollections()
    }

    private func createCollection() {
        isCreating = true
        let collection = DataModel.Collection(title: "", content: "")

        Task {
            defer { isCreating = false }
            try? await collectionRepository.save(collection)
            await loadCollections()
            await syncEngine?.syncNow()
        }
    }

    private func deleteCollection(_ collection: DataModel.Collection) {
        Task {
            try? await collectionRepository.delete(collection)
            await loadCollections()
            await syncEngine?.syncNow()
        }
    }
}

// MARK: - Collection Row

/// A single row in the collections list showing title and content preview.
private struct CollectionRow: View {
    let collection: DataModel.Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collection.title.isEmpty ? "Untitled" : collection.title)
                .font(.headline)
                .foregroundStyle(collection.title.isEmpty ? .secondary : .primary)

            if !collection.content.isEmpty {
                Text(collection.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(collection.modifiedDate, style: .relative)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview("With Collections") {
    NavigationStack {
        CollectionsListView(
            collectionRepository: MockCollectionRepository(),
            syncEngine: nil
        )
        .navigationTitle("Collections")
    }
}

#Preview("Empty") {
    NavigationStack {
        CollectionsListView(
            collectionRepository: InMemoryCollectionRepository(),
            syncEngine: nil
        )
        .navigationTitle("Collections")
    }
}
