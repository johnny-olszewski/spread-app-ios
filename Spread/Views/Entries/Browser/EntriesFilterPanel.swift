import SwiftUI

/// Filter controls shared between the compact filter sheet and the regular trailing card.
///
/// Exposes a List filter (select one or none), Tag filters (multi-select OR), and
/// a "Manage Lists & Tags" stub row for SPRD-223.
struct EntriesFilterPanel: View {
    let lists: [DataModel.List]
    let tags: [DataModel.Tag]
    @Binding var selectedList: DataModel.List?
    @Binding var selectedTagIDs: Set<UUID>
    var onManageListsAndTags: (() -> Void)?

    var body: some View {
        List {
            listSection
            tagSection
            manageSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Sections

    @ViewBuilder
    private var listSection: some View {
        Section("List") {
            filterRow(title: "All Lists", isSelected: selectedList == nil) {
                selectedList = nil
            }
            ForEach(lists) { list in
                filterRow(title: list.name, isSelected: selectedList?.id == list.id) {
                    selectedList = selectedList?.id == list.id ? nil : list
                }
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        Section("Tags") {
            if tags.isEmpty {
                Text("No tags")
                    .foregroundStyle(.secondary)
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
        }
    }

    @ViewBuilder
    private var manageSection: some View {
        Section {
            Button("Manage Lists & Tags") {
                onManageListsAndTags?()
            }
        }
    }

    // MARK: - Helpers

    private func filterRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Empty") {
    EntriesFilterPanel(
        lists: [],
        tags: [],
        selectedList: .constant(nil),
        selectedTagIDs: .constant([])
    )
}
