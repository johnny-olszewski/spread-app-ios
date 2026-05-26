import SwiftUI

/// Displays all tags with task counts and provides navigation to detail/edit.
struct TagManagementView: View {
    let tagRepository: any TagRepository
    var onChanged: () async -> Void = {}

    @State private var tags: [DataModel.Tag] = []

    private func taskCount(_ tag: DataModel.Tag) -> Int {
        tag.tasks.filter { $0.deletedAt == nil }.count
    }

    var body: some View {
        List {
            if tags.isEmpty {
                Text("No tags")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    NavigationLink {
                        TagDetailView(
                            tag: tag,
                            tagRepository: tagRepository,
                            onDeleted: {
                                tags.removeAll { $0.id == tag.id }
                                Task { await onChanged() }
                            },
                            onRenamed: {
                                Task { await onChanged() }
                            }
                        )
                    } label: {
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Text("\(taskCount(tag)) task\(taskCount(tag) == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .task { tags = await tagRepository.getTags() }
    }
}

#Preview {
    NavigationStack {
        TagManagementView(tagRepository: MockTagRepository())
    }
}
