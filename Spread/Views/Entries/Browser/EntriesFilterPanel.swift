import SwiftUI

/// Filter controls shared between the compact filter sheet and the regular trailing card.
///
/// Exposes a Lists section (select one or none, with "Manage Lists" nav action) and a Tags
/// section (multi-select OR, with "Manage Tags" nav action).
struct EntriesFilterPanel: View {
    let lists: [DataModel.List]
    let tags: [DataModel.Tag]
    @Binding var selectedList: DataModel.List?
    @Binding var selectedTagIDs: Set<UUID>
    var onManageLists: (() -> Void)?
    var onManageTags: (() -> Void)?

    var body: some View {
        List {
            listSection
            tagSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Sections

    @ViewBuilder
    private var listSection: some View {
        Section("Lists") {
            filterRow(title: "All Lists", isSelected: selectedList == nil) {
                selectedList = nil
            }
            ForEach(lists) { list in
                filterRow(title: list.name, isSelected: selectedList?.id == list.id) {
                    selectedList = selectedList?.id == list.id ? nil : list
                }
            }
            manageButton(title: "Manage Lists", action: onManageLists)
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
            manageButton(title: "Manage Tags", action: onManageTags)
        }
    }

    // MARK: - Row Builders

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

    private func manageButton(title: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.footnote.weight(.semibold))
            }
        }
        .buttonStyle(.plain)
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
