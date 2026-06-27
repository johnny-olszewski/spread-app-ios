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
struct EntryListView<TrailingContent: View>: View {

    // MARK: - Properties

    let sections: [EntryList.Section]
    let configurationMap: EntryRowView.ConfigurationMap
    let sectionHeaderTrailingContent: ((EntryList.Section) -> TrailingContent)?

    init(
        sections: [EntryList.Section],
        configurationMap: EntryRowView.ConfigurationMap,
        @ViewBuilder sectionHeaderTrailingContent: @escaping (EntryList.Section) -> TrailingContent
    ) {
        self.sections = sections
        self.configurationMap = configurationMap
        self.sectionHeaderTrailingContent = sectionHeaderTrailingContent
    }

    init(
        sections: [EntryList.Section],
        configurationMap: EntryRowView.ConfigurationMap
    ) where TrailingContent == EmptyView {
        self.sections = sections
        self.configurationMap = configurationMap
        self.sectionHeaderTrailingContent = nil
    }

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
                            if let trailing = sectionHeaderTrailingContent {
                                trailing(section)
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
    EntryListView(sections: sections, configurationMap: configMap)
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

