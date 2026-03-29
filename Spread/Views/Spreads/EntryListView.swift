import SwiftUI

/// Displays a list of entries with period-appropriate grouping.
///
/// Grouping rules:
/// - Year spread: Groups by month
/// - Month spread: Groups by day
/// - Day spread: Flat list (no grouping)
/// - Multiday spread: Groups by day within range
///
/// Uses `EntryRowView` for consistent entry rendering across all spread types.
struct EntryListView: View {

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Properties

    /// The spread data model containing entries.
    let spreadDataModel: SpreadDataModel

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The current date for determining past event status (v2 only).
    let today: Date

    /// Callback when an entry is tapped for editing.
    var onEdit: ((any Entry) -> Void)?

    /// Callback when an entry should be deleted.
    var onDelete: ((any Entry) -> Void)?

    /// Callback when a task is marked complete.
    var onComplete: ((DataModel.Task) -> Void)?

    /// Callback when an entry should be migrated.
    var onMigrate: ((any Entry) -> Void)?

    // MARK: - Computed Properties

    /// Active (non-migrated) entries combined from the spread data model.
    private var activeEntries: [any Entry] {
        if isMultidaySpread {
            var entries: [any Entry] = []
            entries.append(contentsOf: activeTasks)
            return entries
        }

        var entries: [any Entry] = []
        entries.append(contentsOf: activeTasks)
        entries.append(contentsOf: activeNotes)
        return entries
    }

    /// Tasks that are not migrated on this spread.
    private var activeTasks: [DataModel.Task] {
        spreadDataModel.tasks.filter { task in
            !isMigratedOnSpread(task)
        }
    }

    /// Notes that are not migrated on this spread.
    private var activeNotes: [DataModel.Note] {
        if isMultidaySpread {
            return []
        }
        return spreadDataModel.notes.filter { note in
            !isMigratedOnSpread(note)
        }
    }

    /// Tasks migrated from this spread (have a migrated assignment on this spread).
    private var migratedTasks: [DataModel.Task] {
        spreadDataModel.tasks.filter { task in
            isMigratedOnSpread(task)
        }
    }

    /// Notes migrated from this spread (have a migrated assignment on this spread).
    private var migratedNotes: [DataModel.Note] {
        if isMultidaySpread {
            return []
        }
        return spreadDataModel.notes.filter { note in
            isMigratedOnSpread(note)
        }
    }

    /// Formatter for computing migration destination labels.
    private var destinationFormatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: calendar)
    }

    /// Grouped sections for display (active entries only).
    private var sections: [EntryListSection] {
        let grouper = EntryListGrouper(
            period: spreadDataModel.spread.period,
            spreadDate: spreadDataModel.spread.date,
            spreadStartDate: spreadDataModel.spread.startDate,
            spreadEndDate: spreadDataModel.spread.endDate,
            calendar: calendar
        )
        return grouper.group(activeEntries)
    }

    private var isMultidaySpread: Bool {
        spreadDataModel.spread.period == .multiday
    }

    private var multidayColumnCount: Int {
        MultidaySectionLayout.columnCount(for: horizontalSizeClass)
    }

    /// Whether there are any entries (active or migrated) to display.
    private var hasAnyEntries: Bool {
        !activeEntries.isEmpty || !migratedTasks.isEmpty || !migratedNotes.isEmpty
    }

    // MARK: - Body

    var body: some View {
        if isMultidaySpread {
            multidayEntryGrid
        } else if hasAnyEntries {
            entryList
        } else {
            emptyState
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var entryList: some View {
        List {
            ForEach(sections) { section in
                if section.title.isEmpty {
                    // Flat list (day spread) - no section header
                    ForEach(section.entries, id: \.id) { entry in
                        entryRow(for: entry)
                            .listRowBackground(Color.clear)
                    }
                } else {
                    // Grouped list with section header
                    Section(section.title) {
                        ForEach(section.entries, id: \.id) { entry in
                            entryRow(for: entry)
                                .listRowBackground(Color.clear)
                        }
                    }
                }
            }

            // Collapsible migrated entries section
            MigratedEntriesSection(
                spread: spreadDataModel.spread,
                migratedTasks: migratedTasks,
                migratedNotes: migratedNotes,
                calendar: calendar,
                onEdit: { entry in onEdit?(entry) }
            )
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.list)
    }

    private var multidayEntryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
                    count: multidayColumnCount
                ),
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(sections) { section in
                    multidayDaySection(section)
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid)
    }

    @ViewBuilder
    private func entryRow(for entry: any Entry) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task)
            }
        case .event:
            EmptyView()
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note)
            }
        }
    }

    private func taskRow(_ task: DataModel.Task) -> some View {
        EntryRowView(
            task: task,
            migrationDestination: destinationFormatter.destination(for: task, from: spreadDataModel.spread),
            onComplete: { onComplete?(task) },
            onMigrate: { onMigrate?(task) },
            onEdit: { onEdit?(task) },
            onDelete: { onDelete?(task) },
            opensEditOnTap: true
        )
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(task.title))
    }

    private func noteRow(_ note: DataModel.Note) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: destinationFormatter.destination(for: note, from: spreadDataModel.spread),
            onMigrate: { onMigrate?(note) },
            onEdit: { onEdit?(note) },
            onDelete: { onDelete?(note) }
        )
    }

    @ViewBuilder
    private func multidayDaySection(_ section: EntryListSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(SpreadTheme.Typography.title3)
                .foregroundStyle(.primary)

            if section.entries.isEmpty {
                Text("No tasks for this day.")
                    .font(SpreadTheme.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(
                        Definitions.AccessibilityIdentifiers.SpreadContent.multidayEmptyState(
                            multidaySectionDateID(for: section.date)
                        )
                    )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(section.entries, id: \.id) { entry in
                        entryRow(for: entry)
                            .padding(.vertical, 8)

                        if entry.id != section.entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SpreadTheme.Paper.primary.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12))
        )
        .accessibilityIdentifier(
            Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection(
                multidaySectionDateID(for: section.date)
            )
        )
    }

    private func multidaySectionDateID(for date: Date) -> String {
        Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: date, calendar: calendar)
    }

    // MARK: - Helpers

    /// Whether a task has a migrated assignment on this spread.
    private func isMigratedOnSpread(_ task: DataModel.Task) -> Bool {
        task.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(
                period: spreadDataModel.spread.period,
                date: spreadDataModel.spread.date,
                calendar: calendar
            )
        }
    }

    /// Whether a note has a migrated assignment on this spread.
    private func isMigratedOnSpread(_ note: DataModel.Note) -> Bool {
        note.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(
                period: spreadDataModel.spread.period,
                date: spreadDataModel.spread.date,
                calendar: calendar
            )
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

enum MultidaySectionLayout {
    static func columnCount(for horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        horizontalSizeClass == .regular ? 2 : 1
    }
}

// MARK: - Preview

#Preview("Year Spread - Grouped by Month") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .year, date: today, calendar: calendar)
    let jan15 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    let feb10 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "January task 1", date: jan15),
            DataModel.Task(title: "January task 2", date: jan15),
            DataModel.Task(title: "February task", date: feb10)
        ],
        notes: [],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Month Spread - Grouped by Day") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .month, date: today, calendar: calendar)
    let day5 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
    let day10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Day 5 task", date: day5),
            DataModel.Task(title: "Day 10 task", date: day10)
        ],
        notes: [],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Day Spread - Flat List") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Task 1", date: today),
            DataModel.Task(title: "Task 2", date: today)
        ],
        notes: [DataModel.Note(title: "A note", date: today)],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Empty State") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(spread: spread)
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("Multiday Spread - Grouped by Day") {
    let calendar = Calendar.current
    let today = Date()
    let startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
    let endDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12))!
    let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: calendar)
    let day6 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
    let day8 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 8))!
    let day10 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Day 6 task", date: day6),
            DataModel.Task(title: "Day 8 task 1", date: day8),
            DataModel.Task(title: "Day 8 task 2", date: day8)
        ],
        notes: [
            DataModel.Note(title: "Day 10 note", date: day10)
        ],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let dataModel = SpreadDataModel(
        spread: spread,
        tasks: [
            DataModel.Task(title: "Open task", date: today, status: .open),
            DataModel.Task(title: "Complete task", date: today, status: .complete),
            DataModel.Task(title: "Migrated task", date: today, status: .migrated),
            DataModel.Task(title: "Cancelled task", date: today, status: .cancelled)
        ],
        notes: [
            DataModel.Note(title: "Active note", date: today, status: .active),
            DataModel.Note(title: "Migrated note", date: today, status: .migrated)
        ],
        events: []
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}
