import SwiftUI

/// Filter controls shared between the compact filter sheet and the regular trailing card.
///
/// Exposes a Lists section (select one or none, with "Manage Lists" nav action) and a Tags
/// section (multi-select OR, with "Manage Tags" nav action). Inline creation is supported
/// when `onCreateList` or `onCreateTag` callbacks are provided.
struct EntriesFilterPanel: View {
    let lists: [DataModel.List]
    let tags: [DataModel.Tag]
    @Binding var selectedList: DataModel.List?
    @Binding var selectedTagIDs: Set<UUID>
    var onManageLists: (() -> Void)?
    var onManageTags: (() -> Void)?
    var onCreateList: ((String) async throws -> Void)?
    var onCreateTag: ((String) async throws -> Void)?

    @State private var isCreatingList = false
    @State private var newListName = ""
    @State private var isCreatingTag = false
    @State private var newTagName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                listSection
                sectionDivider
                tagSection
            }
            .padding(16)
        }
        .alert("New List", isPresented: $isCreatingList) {
            TextField("List name", text: $newListName)
            Button("Create") { createList() }
            Button("Cancel", role: .cancel) { newListName = "" }
        }
        .alert("New Tag", isPresented: $isCreatingTag) {
            TextField("Tag name", text: $newTagName)
            Button("Create") { createTag() }
            Button("Cancel", role: .cancel) { newTagName = "" }
        }
    }

    // MARK: - Sections

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Lists")
            filterRow(title: "All", isSelected: selectedList == nil) {
                selectedList = nil
            }
            ForEach(lists) { list in
                filterRow(title: list.name, isSelected: selectedList?.id == list.id) {
                    selectedList = selectedList?.id == list.id ? nil : list
                }
            }
            if onCreateList != nil {
                actionRow(title: "New List…") { isCreatingList = true }
            }
            actionRow(title: "Manage Lists", trailing: chevron, action: onManageLists)
        }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Tags")
            if tags.isEmpty {
                Text("No tags")
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(tags) { tag in
                    filterRow(title: tag.name, isSelected: selectedTagIDs.contains(tag.id)) {
                        if selectedTagIDs.contains(tag.id) {
                            selectedTagIDs.remove(tag.id)
                        } else {
                            selectedTagIDs.insert(tag.id)
                        }
                    }
                }
            }
            if onCreateTag != nil {
                actionRow(title: "New Tag…") { isCreatingTag = true }
            }
            actionRow(title: "Manage Tags", trailing: chevron, action: onManageTags)
        }
    }

    // MARK: - Row Builders

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(SpreadTheme.Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
    }

    private func filterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(SpreadTheme.Typography.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(SpreadTheme.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func actionRow(title: String, trailing: (some View)? = Optional<EmptyView>.none, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title)
                    .font(SpreadTheme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                trailing
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(SpreadTheme.Typography.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        guard !name.isEmpty else { return }
        Task { try? await onCreateList?(name) }
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        newTagName = ""
        guard !name.isEmpty else { return }
        Task { try? await onCreateTag?(name) }
    }
}

#Preview("With data") {
    EntriesFilterPanel(
        lists: [DataModel.List(name: "Work"), DataModel.List(name: "Home")],
        tags: [DataModel.Tag(name: "EOY"), DataModel.Tag(name: "Urgent")],
        selectedList: .constant(nil),
        selectedTagIDs: .constant([])
    )
}

#Preview("Empty") {
    EntriesFilterPanel(
        lists: [],
        tags: [],
        selectedList: .constant(nil),
        selectedTagIDs: .constant([])
    )
}
