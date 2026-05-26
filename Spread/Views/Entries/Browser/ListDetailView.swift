import SwiftUI

/// Detail view for a single List — supports inline rename and delete with confirmation.
struct ListDetailView: View {
    let list: DataModel.List
    let listRepository: any ListRepository
    var onDeleted: () -> Void = {}
    var onRenamed: () -> Void = {}

    @State private var editedName: String
    @State private var showDeleteConfirmation = false
    @State private var showEmptyNameAlert = false
    @Environment(\.dismiss) private var dismiss

    init(
        list: DataModel.List,
        listRepository: any ListRepository,
        onDeleted: @escaping () -> Void = {},
        onRenamed: @escaping () -> Void = {}
    ) {
        self.list = list
        self.listRepository = listRepository
        self.onDeleted = onDeleted
        self.onRenamed = onRenamed
        self._editedName = State(initialValue: list.name)
    }

    // MARK: - Derived

    private var taskCount: Int {
        list.tasks.filter { $0.deletedAt == nil }.count
    }

    // MARK: - Body

    var body: some View {
        List {
            Section("Name") {
                TextField("List name", text: $editedName)
                    .onSubmit { commitRename() }
            }

            Section {
                LabeledContent("Tasks", value: "\(taskCount)")
            }

            Section {
                Button("Delete List", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { commitRename() }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .confirmationDialog(
            "Delete '\(list.name)'?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deleting '\(list.name)' will remove it from \(taskCount) task\(taskCount == 1 ? "" : "s"). This cannot be undone."
            )
        }
        .alert("Name Cannot Be Empty", isPresented: $showEmptyNameAlert) {
            Button("OK") { editedName = list.name }
        }
    }

    // MARK: - Actions

    private func commitRename() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyNameAlert = true
            return
        }
        guard trimmed != list.name else { return }
        list.name = trimmed
        list.nameUpdatedAt = .now
        Task {
            try? await listRepository.save(list)
            onRenamed()
        }
    }

    private func performDelete() {
        Task {
            try? await listRepository.delete(list)
            onDeleted()
            dismiss()
        }
    }
}
