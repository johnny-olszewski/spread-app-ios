import SwiftUI

struct TaskSearchView: View {
    let journalManager: JournalManager
    let isActive: Bool
    let onOpenTask: (UUID, SpreadHeaderNavigatorModel.Selection?) -> Void

    @State private var searchText = ""
    @State private var isSearchPresented = false

    private var sections: [TaskSearchSection] {
        TaskSearchSectionBuilder(journalManager: journalManager).build(searchText: searchText)
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        Button {
                            onOpenTask(row.taskID, row.selection)
                        } label: {
                            TaskSearchRowContent(
                                title: row.title,
                                status: row.status,
                                subtitle: subtitle(for: row)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            Definitions.AccessibilityIdentifiers.Search.row(row.taskID)
                        )
                    }
                } header: {
                    Text(section.title)
                }
                .accessibilityIdentifier(
                    Definitions.AccessibilityIdentifiers.Search.section(section.token)
                )
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Search")
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search tasks"
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Search.screen)
        .task(id: isActive) {
            guard isActive else { return }
            await Task.yield()
            isSearchPresented = true
        }
        .onChange(of: isActive) { _, newValue in
            guard newValue else { return }
            Task { @MainActor in
                await Task.yield()
                isSearchPresented = true
            }
        }
    }

    private func subtitle(for row: TaskSearchSection.Row) -> String {
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone
        formatter.dateStyle = .medium
        return "\(row.period.displayName): \(formatter.string(from: row.date))"
    }
}

private struct TaskSearchRowContent: View {
    let title: String
    let status: DataModel.Task.Status
    let subtitle: String

    var body: some View {
        HStack(spacing: SpreadTheme.Spacing.entryIconSpacing) {
            StatusIcon(entryType: .task, taskStatus: status, size: .body)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
