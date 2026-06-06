import SwiftUI

/// Renders a pre-computed list of entry sections.
///
/// `EntryListView` is a pure renderer — it knows nothing about `SpreadDataModel` or
/// period-based grouping. Callers compute `[EntryList.Section]` and configure an
/// `EntryRowView.ConfigurationMap` map before passing them here.
///
/// Use `style: .list` (default) for a standalone scrollable `List`. Use `style: .inline`
/// to embed the rows inside an existing scroll container (e.g., Month or Year views) —
/// this produces a `VStack` with dividers and no own scroll view.
///
/// Use `MultidayEntryGridView` for multiday spread grid layouts.
struct EntryListView: View {

    // MARK: - Properties

    let sections: [EntryList.Section]
    let configurationMap: EntryRowView.ConfigurationMap
    var onAddTask: (@MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void)?
    var availableLists: [DataModel.List] = []
    var availableTags: [DataModel.Tag] = []

    // MARK: - Computed

    private static var rowInsets: EdgeInsets {
        EdgeInsets(
            top: SpreadTheme.Spacing.entryRowVertical,
            leading: 16,
            bottom: SpreadTheme.Spacing.entryRowVertical,
            trailing: 16
        )
    }

    private var hasAnyEntries: Bool {
        sections.contains { !renderableEntries(in: $0).isEmpty }
    }

    // MARK: - Body

    var body: some View {
        LazyVStack {
            ForEach(sections) { section in
                if shouldRender(section) {
                    VStack(alignment: .leading, spacing: section.rowSpacing) {
                        HStack {
                            Text(section.title)
                            
                            Spacer()
                            
                            if let headerButtonViewModel = section.headerButtonViewModel {
                                SpreadButton(viewModel: headerButtonViewModel)
                            }
                        }
                        .padding(.leading, section.rowAreaPadding.leading + section.rowInsets.leading)
                        .padding(.trailing, section.rowAreaPadding.trailing + section.rowInsets.trailing)
                        
                        VStack {
                            ForEach(renderableEntries(in: section), id: \.id) { entry in
                                if let configuration = rowConfiguration(for: entry, in: section) {
                                    EntryRowView(entry: entry, configuration: configuration)
                                        .padding(.top, section.rowInsets.top)
                                        .padding(.bottom, section.rowInsets.bottom)
                                        .padding(.leading, section.rowInsets.leading)
                                        .padding(.trailing,  section.rowInsets.trailing)
                                }
                            }
                        }
                        .padding(.top, section.rowAreaPadding.top)
                        .padding(.bottom, section.rowAreaPadding.bottom)
                        .padding(.leading, section.rowAreaPadding.leading)
                        .padding(.trailing,  section.rowAreaPadding.trailing)
                    }
                    .padding(.vertical, section.style?.verticalPadding ?? 0)
                    .background {
                        if case .card(let color) = section.style {
                            RoundedRectangle(cornerRadius: SpreadTheme.CornerRadius.section)
                                .stroke(color.opacity(0.7), lineWidth: 1)
                                .fill(color.opacity(0.45))
                        }
                    }
                }
            }
        }
        .conditionalScrollView()
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.list)
    }

    private func rowConfiguration(
        for entry: any Entry,
        in section: EntryList.Section
    ) -> EntryRowView.Configuration? {
        (section.configurationMap ?? configurationMap)[ObjectIdentifier(type(of: entry))]
    }

    private func renderableEntries(in section: EntryList.Section) -> [any Entry] {
        section.entries.filter { rowConfiguration(for: $0, in: section) != nil }
    }

    private func shouldRender(_ section: EntryList.Section) -> Bool {
        !renderableEntries(in: section).isEmpty
    }

    // MARK: - Empty State (list style only)

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
    let configMap: EntryRowView.ConfigurationMap = [
        DataModel.Task.configurationKey: EntryRowView.Configuration(
            isGreyedOut: { entry in entry.entryType == .task && (entry.status == .complete || entry.status == .cancelled) },
            hasStrikethrough: { entry in entry.status == .cancelled }
        ),
        DataModel.Note.configurationKey: EntryRowView.Configuration()
    ]
    EntryListView(sections: sections, configurationMap: configMap)
}

#Preview("Day Spread - With Add Task") {
    let calendar = Calendar.current
    let today = Date()
    let tasks = [DataModel.Task(title: "Existing task", date: today)]
    let sections = [EntryList.Section(id: "preview", title: "", date: today, entries: tasks, creationPeriod: .day, creationDate: today)]
    let configMap: EntryRowView.ConfigurationMap = [
        DataModel.Task.configurationKey: EntryRowView.Configuration(
            isGreyedOut: { entry in entry.entryType == .task && (entry.status == .complete || entry.status == .cancelled) },
            hasStrikethrough: { entry in entry.status == .cancelled }
        ),
        DataModel.Note.configurationKey: EntryRowView.Configuration()
    ]
    EntryListView(sections: sections, configurationMap: configMap, onAddTask: { _, _, _, _, _ in })
}

#Preview("Empty State") {
    EntryListView(sections: [], configurationMap: [:])
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
    let configMap: EntryRowView.ConfigurationMap = [
        DataModel.Task.configurationKey: EntryRowView.Configuration(
            isGreyedOut: { entry in entry.entryType == .task && (entry.status == .complete || entry.status == .cancelled) },
            hasStrikethrough: { entry in entry.status == .cancelled }
        ),
        DataModel.Note.configurationKey: EntryRowView.Configuration()
    ]
    EntryListView(sections: sections, configurationMap: configMap)
}

// MARK: - Add Task Button

/// Tappable "Add Task" affordance that presents a popover for quick task entry.
///
/// On regular-width (iPad), a true popover appears with an arrow on the leading edge.
/// On compact-width (iPhone), it becomes a small bottom sheet via `presentationDetents`.
/// When `availableLists` or `availableTags` are non-empty, keyboard toolbar buttons
/// above the text field allow single-select assignment before saving.
struct AddTaskButton: View {

    let date: Date
    let period: Period
    let availableLists: [DataModel.List]
    let availableTags: [DataModel.Tag]
    let onAddTask: @MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void

    @State private var isPresented = false
    @State private var title = ""
    @State private var selectedList: DataModel.List?
    @State private var selectedTag: DataModel.Tag?
    @FocusState private var isTitleFocused: Bool

    init(
        date: Date,
        period: Period,
        availableLists: [DataModel.List] = [],
        availableTags: [DataModel.Tag] = [],
        onAddTask: @escaping @MainActor (String, Date, Period, DataModel.List?, DataModel.Tag?) async throws -> Void
    ) {
        self.date = date
        self.period = period
        self.availableLists = availableLists
        self.availableTags = availableTags
        self.onAddTask = onAddTask
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                Text("Add Task")
                    .font(SpreadTheme.Typography.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .leading
        ) {
            popoverContent
                .presentationDetents([.height(200)])
        }
    }

    // MARK: - Popover Content

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("New Task")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            TextField("Task title", text: $title)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .onSubmit { submitTask() }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if !availableLists.isEmpty || !availableTags.isEmpty {
                HStack(spacing: 8) {
                    if !availableLists.isEmpty { listPickerButton }
                    if !availableTags.isEmpty { tagPickerButton }
                    Spacer()
                    Button("Add") { submitTask() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                HStack {
                    Spacer()
                    Button("Add") { submitTask() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 280)
        .task { isTitleFocused = true }
        .onDisappear { clearState() }
    }

    // MARK: - Picker Buttons

    private var listPickerButton: some View {
        Menu {
            if selectedList != nil {
                Button("Clear List", role: .destructive) { selectedList = nil }
            }
            ForEach(availableLists) { list in
                Button {
                    selectedList = list
                } label: {
                    if selectedList?.id == list.id {
                        Label(list.name, systemImage: "checkmark")
                    } else {
                        Text(list.name)
                    }
                }
            }
        } label: {
            Label(
                selectedList?.name ?? "List",
                systemImage: selectedList != nil ? "folder.fill" : "folder"
            )
            .foregroundStyle(selectedList != nil ? SpreadTheme.Accent.todaySelectedEmphasis : .secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var tagPickerButton: some View {
        Menu {
            if selectedTag != nil {
                Button("Clear Tag", role: .destructive) { selectedTag = nil }
            }
            ForEach(availableTags) { tag in
                Button {
                    selectedTag = tag
                } label: {
                    if selectedTag?.id == tag.id {
                        Label(tag.name, systemImage: "checkmark")
                    } else {
                        Text(tag.name)
                    }
                }
            }
        } label: {
            Label(
                selectedTag?.name ?? "Tag",
                systemImage: selectedTag != nil ? "tag.fill" : "tag"
            )
            .foregroundStyle(selectedTag != nil ? SpreadTheme.Accent.todaySelectedEmphasis : .secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Helpers

    private func submitTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let list = selectedList
        let tag = selectedTag
        isPresented = false
        Task { @MainActor in try? await onAddTask(trimmed, date, period, list, tag) }
    }

    private func dismiss() {
        isPresented = false
    }

    private func clearState() {
        title = ""
        selectedList = nil
        selectedTag = nil
    }
}
