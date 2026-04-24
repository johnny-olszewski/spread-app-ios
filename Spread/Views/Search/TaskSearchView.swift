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
                                bodyPreview: row.bodyPreview,
                                priority: row.priority,
                                dueDateLabel: dueDateLabel(for: row),
                                isDueDateHighlighted: isDueDateHighlighted(for: row),
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
        let assignment = "\(row.period.displayName): \(formatter.string(from: row.date))"
        if row.selection == nil {
            return row.hasPreferredAssignment ? "Assigned: \(assignment)" : "Unassigned"
        }
        return assignment
    }

    private func dueDateLabel(for row: TaskSearchSection.Row) -> String? {
        guard let dueDate = row.dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = journalManager.calendar
        formatter.timeZone = journalManager.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return "Due \(formatter.string(from: dueDate))"
    }

    private func isDueDateHighlighted(for row: TaskSearchSection.Row) -> Bool {
        guard row.status == .open,
              let dueDate = row.dueDate else {
            return false
        }
        return dueDate.startOfDay(calendar: journalManager.calendar) <=
            journalManager.today.startOfDay(calendar: journalManager.calendar)
    }
}

private struct TaskSearchRowContent: View {
    let title: String
    let bodyPreview: String?
    let priority: DataModel.Task.Priority
    let dueDateLabel: String?
    let isDueDateHighlighted: Bool
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

                if priority != .none || dueDateLabel != nil {
                    HStack(spacing: 6) {
                        if let badgeTitle = priority.badgeTitle {
                            Text(badgeTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(priority.badgeColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(priority.badgeColor.opacity(0.35), lineWidth: 1)
                                }
                        }

                        if let dueDateLabel {
                            Text(dueDateLabel)
                                .font(SpreadTheme.Typography.caption)
                                .foregroundStyle(isDueDateHighlighted ? Color.orange : Color.secondary)
                        }
                    }
                }

                if let bodyPreview {
                    Text(bodyPreview)
                        .font(SpreadTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
