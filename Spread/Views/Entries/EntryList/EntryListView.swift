import SwiftUI

/// Renders a pre-computed list of entry sections.
///
/// `EntryListView` is a pure renderer — it knows nothing about `SpreadDataModel` or
/// period-based grouping. Callers compute `[EntryListSection]` using `EntryListGrouper`
/// and configure an `EntryListViewModel` before passing it here.
///
/// Use `MultidayEntryGridView` for multiday spread grid layouts.
struct EntryListView: View {

    // MARK: - Properties

    @Bindable var viewModel: EntryListViewModel

    // MARK: - Computed

    private static let rowInsets = EdgeInsets(
        top: SpreadTheme.Spacing.entryRowVertical,
        leading: 16,
        bottom: SpreadTheme.Spacing.entryRowVertical,
        trailing: 16
    )

    // MARK: - Body

    var body: some View {
        if viewModel.hasAnyEntries || viewModel.onAddTask != nil {
            entryList
        } else {
            emptyState
        }
    }

    // MARK: - List Layouts

    @ViewBuilder
    private var entryList: some View {
        List {
            ForEach(viewModel.sections) { section in
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
    private func sectionRows(_ section: EntryListSection) -> some View {
        ForEach(section.entries, id: \.id) { entry in
            if let configuration = viewModel.configurationMap[entry.entryType] {
                EntryRowView(
                    entry: entry,
                    configuration: configuration,
                    contextualLabel: section.contextualLabel(for: entry)
                )
                .listRowInsets(Self.rowInsets)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }

        if let onAddTask = viewModel.onAddTask {
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
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks = [
        DataModel.Task(title: "Task 1", date: today),
        DataModel.Task(title: "Task 2", date: today)
    ]
    let notes = [DataModel.Note(title: "A note", date: today)]
    let entries: [any Entry] = tasks + notes
    let vm = EntryListViewModel()
    vm.sections = grouper.group(entries)
    vm.calendar = calendar
    vm.today = today
    vm.configurationMap = [
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
    return EntryListView(viewModel: vm)
}

#Preview("Day Spread - With Add Task") {
    let calendar = Calendar.current
    let today = Date()
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks = [DataModel.Task(title: "Existing task", date: today)]
    let vm = EntryListViewModel()
    vm.sections = grouper.group(tasks)
    vm.calendar = calendar
    vm.today = today
    vm.configurationMap = [
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
    vm.onAddTask = { _, _, _ in }
    return EntryListView(viewModel: vm)
}

#Preview("Empty State") {
    let vm = EntryListViewModel()
    return EntryListView(viewModel: vm)
}

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let grouper = EntryListGrouper(
        configuration: .init(),
        period: .day,
        spreadDate: today,
        spreadStartDate: nil,
        spreadEndDate: nil,
        calendar: calendar
    )
    let tasks: [any Entry] = [
        DataModel.Task(title: "Open task", date: today, status: .open),
        DataModel.Task(title: "Complete task", date: today, status: .complete),
        DataModel.Task(title: "Cancelled task", date: today, status: .cancelled)
    ]
    let notes: [any Entry] = [
        DataModel.Note(title: "Active note", date: today, status: .active)
    ]
    let vm = EntryListViewModel()
    vm.sections = grouper.group(tasks + notes)
    vm.calendar = calendar
    vm.today = today
    vm.configurationMap = [
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
    return EntryListView(viewModel: vm)
}
