import SwiftUI

/// Detail view for a single Tag — supports inline rename and delete with confirmation.
struct TagDetailView: View {
    let tag: DataModel.Tag
    let tagRepository: any TagRepository
    var onDeleted: () -> Void = {}
    var onRenamed: () -> Void = {}

    @State private var editedName: String
    @State private var showDeleteConfirmation = false
    @State private var showEmptyNameAlert = false
    @Environment(\.dismiss) private var dismiss

    init(
        tag: DataModel.Tag,
        tagRepository: any TagRepository,
        onDeleted: @escaping () -> Void = {},
        onRenamed: @escaping () -> Void = {}
    ) {
        self.tag = tag
        self.tagRepository = tagRepository
        self.onDeleted = onDeleted
        self.onRenamed = onRenamed
        self._editedName = State(initialValue: tag.name)
    }

    // MARK: - Derived

    private var taskCount: Int {
        tag.tasks.filter { $0.deletedAt == nil }.count
    }

    // MARK: - Body

    var body: some View {
        List {
            Section("Name") {
                TextField("Tag name", text: $editedName)
                    .onSubmit { commitRename() }
            }

            Section {
                LabeledContent("Tasks", value: "\(taskCount)")
            }

            Section {
                Button("Delete Tag", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { commitRename() }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog(
            "Delete '\(tag.name)'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deleting '\(tag.name)' will remove it from \(taskCount) task\(taskCount == 1 ? "" : "s"). This cannot be undone."
            )
        }
        .alert("Name Cannot Be Empty", isPresented: $showEmptyNameAlert) {
            Button("OK") { editedName = tag.name }
        }
    }

    // MARK: - Actions

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyNameAlert = true
            return
        }
        guard trimmed != tag.name else { return }
        tag.name = trimmed
        tag.nameUpdatedAt = .now
        Task {
            try? await tagRepository.save(tag)
            onRenamed()
        }
    }

    private func performDelete() {
        Task {
            try? await tagRepository.delete(tag)
            onDeleted()
            dismiss()
        }
    }
}
