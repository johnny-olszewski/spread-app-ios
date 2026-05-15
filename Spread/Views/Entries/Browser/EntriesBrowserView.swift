import SwiftUI

/// The Entries tab — a cross-spread browser for all tasks and notes.
///
/// Shows a Tasks/Notes segmented control pinned at the top via `safeAreaInset`. Tasks mode
/// displays two lifecycle sections (Open, Completed / Cancelled) with List and Tag filtering.
/// Notes mode shows all notes ordered by `createdDate` descending with search only.
///
/// Adapts to horizontal size class: on regular width the filter panel appears as a persistent
/// trailing card (styled to match the day spread timeline card); on compact width it appears
/// as a toolbar-button sheet.
struct EntriesBrowserView: View {
    let journalManager: JournalManager
    let listRepository: any ListRepository
    let tagRepository: any TagRepository
    let onOpenTask: (UUID, SpreadHeaderNavigatorModel.Selection?) -> Void

    @State private var viewModel = EntriesBrowserViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }

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
        contentList
            .safeAreaInset(edge: .top, spacing: 0) {
                segmentedControlBar
            }
            .safeAreaInset(edge: .trailing, spacing: 0) {
                if isRegular { filterCard }
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

    // MARK: - Segmented Control Bar

    private var segmentedControlBar: some View {
        Picker("Content", selection: $viewModel.contentMode) {
            Text("Tasks").tag(EntriesBrowserContentMode.tasks)
            Text("Notes").tag(EntriesBrowserContentMode.notes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Content List

    private var contentList: some View {
        List {
            switch viewModel.contentMode {
            case .tasks:
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
            case .notes:
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
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Task List Helpers

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

    // MARK: - Filter Card (Regular)

    private var filterCard: some View {
        ScrollView {
            EntriesFilterPanel(
                lists: viewModel.lists,
                tags: viewModel.tags,
                selectedList: $viewModel.selectedList,
                selectedTagIDs: $viewModel.selectedTagIDs
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
        )
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Filter Controls (Compact)

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
