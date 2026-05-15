import SwiftUI

/// The Entries tab — a cross-spread browser for all tasks and notes.
///
/// Shows a Tasks/Notes segmented control at the top. Tasks mode displays two lifecycle
/// sections (Open, Completed / Cancelled) with List and Tag filtering. Notes mode shows
/// all notes ordered by `createdDate` descending with search only.
///
/// Adapts to horizontal size class: on regular width the filter panel appears as a
/// persistent trailing card; on compact width it appears as a toolbar-button sheet.
struct EntriesBrowserView: View {
    let journalManager: JournalManager
    let listRepository: any ListRepository
    let tagRepository: any TagRepository
    let onOpenTask: (UUID, SpreadHeaderNavigatorModel.Selection?) -> Void

    @State private var viewModel = EntriesBrowserViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass != .compact }

    private var taskSections: [TaskBrowserSection] {
        TaskBrowserSectionBuilder().build(
            tasks: journalManager.tasks,
            selectedList: viewModel.selectedList,
            selectedTagIDs: viewModel.selectedTagIDs,
            searchText: viewModel.searchText
        )
    }

    private var filteredNotes: [DataModel.Note] {
        let sorted = journalManager.notes.sorted { $0.createdDate > $1.createdDate }
        guard !viewModel.searchText.isEmpty else { return sorted }
        let query = viewModel.searchText.lowercased()
        return sorted.filter { note in
            note.title.lowercased().contains(query)
                || note.content.lowercased().contains(query)
        }
    }

    var body: some View {
        Group {
            if isRegular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search entries")
        .toolbar {
            if !isRegular {
                ToolbarItem(placement: .topBarTrailing) {
                    filterToolbarButton
                }
            }
        }
        .sheet(isPresented: $viewModel.isFilterSheetPresented) {
            filterSheet
        }
        .task {
            await viewModel.loadListsAndTags(
                listRepository: listRepository,
                tagRepository: tagRepository
            )
        }
    }

    // MARK: - Layouts

    private var regularLayout: some View {
        HStack(spacing: 0) {
            mainContent
            Divider()
            EntriesFilterPanel(
                lists: viewModel.lists,
                tags: viewModel.tags,
                selectedList: $viewModel.selectedList,
                selectedTagIDs: $viewModel.selectedTagIDs
            )
            .frame(width: 280)
        }
    }

    private var compactLayout: some View {
        mainContent
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            contentModePicker
            Divider()
            switch viewModel.contentMode {
            case .tasks: taskList
            case .notes: noteList
            }
        }
    }

    private var contentModePicker: some View {
        Picker("Content", selection: $viewModel.contentMode) {
            Text("Tasks").tag(EntriesBrowserContentMode.tasks)
            Text("Notes").tag(EntriesBrowserContentMode.notes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Task List

    private var taskList: some View {
        List {
            ForEach(taskSections) { section in
                Section(section.title) {
                    if section.rows.isEmpty {
                        emptyRow(for: section)
                    } else {
                        ForEach(section.rows) { row in
                            Button {
                                onOpenTask(row.task.id, nil)
                            } label: {
                                EntryRowView(task: row.task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func emptyRow(for section: TaskBrowserSection) -> some View {
        Text(emptyMessage(for: section))
            .foregroundStyle(.secondary)
            .font(.subheadline)
    }

    private func emptyMessage(for section: TaskBrowserSection) -> String {
        let hasFilters = viewModel.hasActiveFilters || !viewModel.searchText.isEmpty
        switch section.kind {
        case .open:
            return hasFilters ? "No open tasks match" : "No open tasks"
        case .terminal:
            return hasFilters ? "No completed tasks match" : "No completed tasks"
        }
    }

    // MARK: - Note List

    private var noteList: some View {
        List {
            if filteredNotes.isEmpty {
                Text(viewModel.searchText.isEmpty ? "No notes" : "No results")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(filteredNotes) { note in
                    EntryRowView(note: note)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Filter Controls

    private var filterToolbarButton: some View {
        Button {
            viewModel.isFilterSheetPresented = true
        } label: {
            Image(systemName: viewModel.hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(viewModel.hasActiveFilters ? "Filter (active)" : "Filter")
    }

    private var filterSheet: some View {
        NavigationStack {
            EntriesFilterPanel(
                lists: viewModel.lists,
                tags: viewModel.tags,
                selectedList: $viewModel.selectedList,
                selectedTagIDs: $viewModel.selectedTagIDs
            )
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { viewModel.isFilterSheetPresented = false }
                }
                if viewModel.hasActiveFilters {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") { viewModel.clearFilters() }
                    }
                }
            }
        }
    }
}

#Preview("Compact") {
    NavigationStack {
        EntriesBrowserView(
            journalManager: .previewInstance,
            listRepository: EmptyListRepository(),
            tagRepository: EmptyTagRepository()
        ) { _, _ in }
    }
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("Regular") {
    NavigationStack {
        EntriesBrowserView(
            journalManager: .previewInstance,
            listRepository: EmptyListRepository(),
            tagRepository: EmptyTagRepository()
        ) { _, _ in }
    }
    .environment(\.horizontalSizeClass, .regular)
}
