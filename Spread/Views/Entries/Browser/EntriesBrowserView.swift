import SwiftUI

/// The Entries tab — a cross-spread browser for all tasks and notes.
///
/// Shows a Tasks/Notes segmented control pinned at the top via `safeAreaInset`. Tasks mode
/// displays two lifecycle sections (Open, Completed / Cancelled) with List and Tag filtering.
/// Notes mode shows all notes ordered by `createdDate` descending with search only.
///
/// Adapts to horizontal size class:
/// - **Compact**: a filter button in the toolbar opens a sheet whose `NavigationStack` hosts
///   the filter panel at its root. Tapping "Manage Lists" or "Manage Tags" pushes the
///   respective management view within the same sheet.
/// - **Regular**: a persistent trailing card shows the filter panel. Tapping "Manage Lists"
///   or "Manage Tags" presents a sheet pre-navigated to that management view; the user can
///   navigate back to the filter root within the sheet.
struct EntriesBrowserView: View {
    let journalManager: JournalManager
    let listRepository: any ListRepository
    let tagRepository: any TagRepository
    let onOpenTask: (UUID, SpreadHeaderNavigatorModel.Selection?) -> Void

    @State private var viewModel = EntriesBrowserViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }

    private var taskSections: [TaskBrowserSection] {
        TaskBrowserSectionBuilder(calendar: journalManager.calendar, today: journalManager.today).build(
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
        HStack(alignment: .top, spacing: 0) {
            contentList
            
            if isRegular {
                filterCard
            }
        }
        .dotGridBackground(.paper, ignoresSafeAreaEdges: .all)
        .safeAreaInset(edge: .top, spacing: 0) {
            segmentedControlBar
        }
        .searchable(text: $viewModel.searchText, prompt: "Search entries")
        .toolbar {
            if !isRegular {
                ToolbarItem(placement: .topBarTrailing) {
                    filterToolbarButton
                }
            }
        }
        .sheet(isPresented: $viewModel.isFilterSheetPresented, onDismiss: resetFilterNavPath) {
            filterSheet
        }
        .sheet(isPresented: $viewModel.isManagementSheetPresented, onDismiss: resetManagementState) {
            managementSheet
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
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        } else {
                            ForEach(section.rows) { row in
                                EntryRowView(
                                    entry: row.task,
                                    configuration: EntryRowConfiguration(
                                        effectiveTaskStatus: { $0.displayTaskStatus },
                                        isGreyedOut: { entry in
                                            guard let s = entry.displayTaskStatus else { return false }
                                            return s == .complete || s == .migrated || s == .cancelled
                                        },
                                        hasStrikethrough: { entry in entry.displayTaskStatus == .cancelled },
                                        onEdit: { _ in onOpenTask(row.task.id, nil) }
                                    )
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                    }
                }
            case .notes:
                if filteredNotes.isEmpty {
                    Text(viewModel.searchText.isEmpty ? "No notes" : "No results")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredNotes) { note in
                        EntryRowView(
                            entry: note,
                            configuration: EntryRowConfiguration(
                                isGreyedOut: { entry in (entry as? DataModel.Note)?.status == .migrated }
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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
        case .inbox, .dated:
            return hasFilters ? "No open tasks match" : "No open tasks"
        case .terminal:
            return hasFilters ? "No completed tasks match" : "No completed tasks"
        }
    }

    // MARK: - Filter Card (Regular)

    private var filterCard: some View {
        EntriesFilterPanel(
            lists: viewModel.lists,
            tags: viewModel.tags,
            selectedList: $viewModel.selectedList,
            selectedTagIDs: $viewModel.selectedTagIDs,
            onManageLists: {
                viewModel.managementNavPath = [.lists]
                viewModel.isManagementSheetPresented = true
            },
            onManageTags: {
                viewModel.managementNavPath = [.tags]
                viewModel.isManagementSheetPresented = true
            },
            onCreateList: { name in try await createList(name: name) },
            onCreateTag: { name in try await createTag(name: name) }
        )
        .containerRelativeFrame(.horizontal, count: 10, span: 3, spacing: 0)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpreadTheme.Paper.primary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
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
        NavigationStack(path: $viewModel.managementNavPath) {
            EntriesFilterPanel(
                lists: viewModel.lists,
                tags: viewModel.tags,
                selectedList: $viewModel.selectedList,
                selectedTagIDs: $viewModel.selectedTagIDs,
                onManageLists: { viewModel.managementNavPath.append(.lists) },
                onManageTags: { viewModel.managementNavPath.append(.tags) },
                onCreateList: { name in try await createList(name: name) },
                onCreateTag: { name in try await createTag(name: name) }
            )
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ManagementDestination.self, destination: managementDestinationView)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.isFilterSheetPresented = false
                    }
                }
                if viewModel.hasActiveFilters && viewModel.managementNavPath.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear") { viewModel.clearFilters() }
                    }
                }
            }
        }
    }

    // MARK: - Management Sheet (Regular)

    /// Presented from the persistent filter card with the path pre-navigated to the
    /// selected management destination. The user can navigate back to the filter root.
    private var managementSheet: some View {
        NavigationStack(path: $viewModel.managementNavPath) {
            EntriesFilterPanel(
                lists: viewModel.lists,
                tags: viewModel.tags,
                selectedList: $viewModel.selectedList,
                selectedTagIDs: $viewModel.selectedTagIDs,
                onManageLists: { viewModel.managementNavPath.append(.lists) },
                onManageTags: { viewModel.managementNavPath.append(.tags) },
                onCreateList: { name in try await createList(name: name) },
                onCreateTag: { name in try await createTag(name: name) }
            )
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ManagementDestination.self, destination: managementDestinationView)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        viewModel.isManagementSheetPresented = false
                    }
                }
            }
        }
    }

    // MARK: - Shared Navigation Destination

    @ViewBuilder
    private func managementDestinationView(_ destination: ManagementDestination) -> some View {
        switch destination {
        case .lists:
            ListManagementView(
                listRepository: listRepository,
                onChanged: {
                    await viewModel.refreshListsAndTags(
                        listRepository: listRepository,
                        tagRepository: tagRepository
                    )
                }
            )
        case .tags:
            TagManagementView(
                tagRepository: tagRepository,
                onChanged: {
                    await viewModel.refreshListsAndTags(
                        listRepository: listRepository,
                        tagRepository: tagRepository
                    )
                }
            )
        }
    }

    // MARK: - Helpers

    private func resetFilterNavPath() {
        viewModel.managementNavPath = []
    }

    private func resetManagementState() {
        viewModel.managementNavPath = []
    }

    private func createList(name: String) async throws {
        _ = try await journalManager.createList(name: name)
        await viewModel.refreshListsAndTags(listRepository: listRepository, tagRepository: tagRepository)
    }

    private func createTag(name: String) async throws {
        _ = try await journalManager.createTag(name: name)
        await viewModel.refreshListsAndTags(listRepository: listRepository, tagRepository: tagRepository)
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
