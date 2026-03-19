import SwiftUI

/// Plain text editor for a single collection.
///
/// Provides editable title and content fields with debounced auto-save.
/// Changes are persisted to the repository after a brief delay, and
/// `modifiedDate` is updated on each save. Sync is triggered when
/// the user navigates away (disappear).
struct CollectionEditorView: View {

    // MARK: - Properties

    /// The collection being edited.
    let collection: DataModel.Collection

    /// Repository for persisting changes.
    let collectionRepository: any CollectionRepository

    /// Optional sync engine to trigger sync on dismiss.
    let syncEngine: SyncEngine?

    /// Callback to reload the parent list after edits.
    var onEdited: (() -> Void)?

    /// Local copy of the title for editing.
    @State private var title: String

    /// Local copy of the content for editing.
    @State private var content: String

    /// Whether there are unsaved changes.
    @State private var hasUnsavedChanges = false

    /// The debounce task for auto-save.
    @State private var saveTask: Task<Void, Never>?

    /// Debounce interval for auto-save in seconds.
    private let debounceInterval: TimeInterval = 1.0

    // MARK: - Initializer

    init(
        collection: DataModel.Collection,
        collectionRepository: any CollectionRepository,
        syncEngine: SyncEngine?,
        onEdited: (() -> Void)? = nil
    ) {
        self.collection = collection
        self.collectionRepository = collectionRepository
        self.syncEngine = syncEngine
        self.onEdited = onEdited
        self._title = State(initialValue: collection.title)
        self._content = State(initialValue: collection.content)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            titleField
            Divider()
            contentEditor
        }
        .navigationTitle("Collection")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: title) { _, _ in
            scheduleSave()
        }
        .onChange(of: content) { _, _ in
            scheduleSave()
        }
        .onDisappear {
            saveImmediatelyAndSync()
        }
    }

    // MARK: - Subviews

    private var titleField: some View {
        TextField("Title", text: $title)
            .font(.title2.bold())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var contentEditor: some View {
        TextEditor(text: $content)
            .font(.body)
            .padding(.horizontal, 12)
            .scrollContentBackground(.hidden)
    }

    // MARK: - Auto-Save

    private func scheduleSave() {
        hasUnsavedChanges = true
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(debounceInterval))
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    private func save() async {
        guard hasUnsavedChanges else { return }
        collection.title = title
        collection.content = content
        collection.modifiedDate = .now
        try? await collectionRepository.save(collection)
        hasUnsavedChanges = false
        onEdited?()
    }

    private func saveImmediatelyAndSync() {
        saveTask?.cancel()
        Task {
            await save()
            await syncEngine?.syncNow()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CollectionEditorView(
            collection: DataModel.Collection(
                title: "Shopping List",
                content: "Eggs\nMilk\nBread\nButter"
            ),
            collectionRepository: InMemoryCollectionRepository(),
            syncEngine: nil
        )
    }
}

#Preview("Empty Collection") {
    NavigationStack {
        CollectionEditorView(
            collection: DataModel.Collection(title: "", content: ""),
            collectionRepository: InMemoryCollectionRepository(),
            syncEngine: nil
        )
    }
}
