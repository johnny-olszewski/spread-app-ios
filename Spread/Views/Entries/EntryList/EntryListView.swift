import SwiftUI

/// Renders a pre-computed list of entry sections.
///
/// `EntryListView` is a pure renderer — it knows nothing about `SpreadDataModel` or
/// period-based grouping. Callers compute `[EntryList.Section]` and configure an
/// `[EntryType: EntryRowView.Configuration]` map before passing them here.
///
/// Use `MultidayEntryGridView` for multiday spread grid layouts.
struct EntryListView: View {

    // MARK: - Properties

    let sections: [EntryList.Section]
    let configurationMap: [EntryType: EntryRowView.Configuration]
    var onAddTask: (@MainActor (String, Date, Period) async throws -> Void)?

    // MARK: - Computed

    private static let rowInsets = EdgeInsets(
        top: SpreadTheme.Spacing.entryRowVertical,
        leading: 16,
        bottom: SpreadTheme.Spacing.entryRowVertical,
        trailing: 16
    )

    private var hasAnyEntries: Bool {
        !sections.allSatisfy { $0.entries.isEmpty }
    }

    // MARK: - Body

    var body: some View {
        if hasAnyEntries || onAddTask != nil {
            entryList
        } else {
            emptyState
        }
    }

    // MARK: - List Layouts

    @ViewBuilder
    private var entryList: some View {
        List {
            ForEach(sections) { section in
                if section.title.isEmpty {
                    sectionRows(section)
                } else {
                    Section(section.title) {
                        sectionRows(section)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .environment(\.defaultMinListRowHeight, 0)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.list)
    }

    // MARK: - Section Rows

    @ViewBuilder
    private func sectionRows(_ section: EntryList.Section) -> some View {
        ForEach(section.entries, id: \.id) { entry in
            if let configuration = configurationMap[entry.entryType] {
                EntryRowView(
                    entry: entry,
                    configuration: configuration
                )
                .listRowInsets(Self.rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }

        if let onAddTask {
            AddTaskButton(date: section.creationDate, period: section.creationPeriod, onAddTask: onAddTask)
                .listRowInsets(Self.rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries", systemImage: "tray")
        } description: {
            Text("Add tasks or notes to this spread.")
        }
    }
}

// MARK: - Preview

#Preview("Day Spread - Flat List") {
    let calendar = Calendar.current
    let today = Date()
    let tasks = [
        DataModel.Task(title: "Task 1", date: today),
        DataModel.Task(title: "Task 2", date: today)
    ]
    let notes = [DataModel.Note(title: "A note", date: today)]
    let entries: [any Entry] = tasks + notes
    let sections = [EntryList.Section(id: "preview", title: "", date: today, entries: entries, creationPeriod: .day, creationDate: today)]
    let configMap: [EntryType: EntryRowView.Configuration] = [
        .task: EntryRowView.Configuration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                entry.displayTaskStatus.map { $0 == .complete || $0 == .cancelled } ?? false
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            onEdit: { _ in },
            onDelete: { _ in }
        ),
        .note: EntryRowView.Configuration(onEdit: { _ in }, onDelete: { _ in })
    ]
    return EntryListView(sections: sections, configurationMap: configMap)
}

#Preview("Day Spread - With Add Task") {
    let calendar = Calendar.current
    let today = Date()
    let tasks = [DataModel.Task(title: "Existing task", date: today)]
    let sections = [EntryList.Section(id: "preview", title: "", date: today, entries: tasks, creationPeriod: .day, creationDate: today)]
    let configMap: [EntryType: EntryRowView.Configuration] = [
        .task: EntryRowView.Configuration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                entry.displayTaskStatus.map { $0 == .complete || $0 == .cancelled } ?? false
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            onEdit: { _ in },
            onDelete: { _ in }
        ),
        .note: EntryRowView.Configuration(onEdit: { _ in }, onDelete: { _ in })
    ]
    return EntryListView(sections: sections, configurationMap: configMap, onAddTask: { _, _, _ in })
}

#Preview("Empty State") {
    return EntryListView(sections: [], configurationMap: [:])
}

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let entries: [any Entry] = [
        DataModel.Task(title: "Open task", date: today, status: .open),
        DataModel.Task(title: "Complete task", date: today, status: .complete),
        DataModel.Task(title: "Cancelled task", date: today, status: .cancelled),
        DataModel.Note(title: "Active note", date: today, status: .active)
    ]
    let sections = [EntryList.Section(id: "preview", title: "", date: today, entries: entries, creationPeriod: .day, creationDate: today)]
    let configMap: [EntryType: EntryRowView.Configuration] = [
        .task: EntryRowView.Configuration(
            effectiveTaskStatus: { $0.displayTaskStatus },
            isGreyedOut: { entry in
                entry.displayTaskStatus.map { $0 == .complete || $0 == .cancelled } ?? false
            },
            hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
            onEdit: { _ in },
            onDelete: { _ in }
        ),
        .note: EntryRowView.Configuration(onEdit: { _ in }, onDelete: { _ in })
    ]
    return EntryListView(sections: sections, configurationMap: configMap)
}
