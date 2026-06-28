import SwiftUI

/// Displays all lists with task counts and provides navigation to detail/edit.
struct ListManagementView: View {
    let listRepository: any ListRepository
    var onChanged: () async -> Void = {}

    @State private var lists: [DataModel.List] = []

    private func taskCount(_ list: DataModel.List) -> Int {
        list.tasks.filter { $0.deletedAt == nil }.count
    }

    var body: some View {
        List {
            if lists.isEmpty {
                Text("No lists")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(lists) { list in
                    NavigationLink {
                        ListDetailView(
                            list: list,
                            listRepository: listRepository,
                            onDeleted: {
                                lists.removeAll { $0.id == list.id }
                                Task { await onChanged() }
                            },
                            onRenamed: {
                                Task { await onChanged() }
                            }
                        )
                    } label: {
                        HStack {
                            Text(list.name)
                            Spacer()
                            Text("\(taskCount(list)) task\(taskCount(list) == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .font(SpreadTheme.Typography.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Lists")
        .navigationBarTitleDisplayMode(.inline)
        .task { lists = await listRepository.getLists() }
    }
}

#Preview {
    NavigationStack {
        ListManagementView(listRepository: MockListRepository())
    }
}
