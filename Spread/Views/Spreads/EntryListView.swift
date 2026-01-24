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

    // MARK: - Properties

    /// The spread data model containing entries.
    let spreadDataModel: SpreadDataModel

    /// The calendar for date calculations.
    let calendar: Calendar

    /// The current date for determining past event status.
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

    /// All entries combined from the spread data model.
    private var allEntries: [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: spreadDataModel.tasks)
        entries.append(contentsOf: spreadDataModel.events)
        entries.append(contentsOf: spreadDataModel.notes)
        return entries
    }

    /// Grouped sections for display.
    private var sections: [EntryListSection] {
        let grouper = EntryListGrouper(
            period: spreadDataModel.spread.period,
            spreadDate: spreadDataModel.spread.date,
            calendar: calendar
        )
        return grouper.group(allEntries)
    }

    // MARK: - Body

    var body: some View {
        if allEntries.isEmpty {
            emptyState
        } else {
            entryList
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
                    }
                } else {
                    // Grouped list with section header
                    Section(section.title) {
                        ForEach(section.entries, id: \.id) { entry in
                            entryRow(for: entry)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func entryRow(for entry: any Entry) -> some View {
        switch entry.entryType {
        case .task:
            if let task = entry as? DataModel.Task {
                taskRow(task)
            }
        case .event:
            if let event = entry as? DataModel.Event {
                eventRow(event)
            }
        case .note:
            if let note = entry as? DataModel.Note {
                noteRow(note)
            }
        }
    }

    private func taskRow(_ task: DataModel.Task) -> some View {
        EntryRowView(
            task: task,
            migrationDestination: nil, // TODO: SPRD-29 - Add migration destination label
            onComplete: { onComplete?(task) },
            onMigrate: { onMigrate?(task) },
            onEdit: { onEdit?(task) },
            onDelete: { onDelete?(task) }
        )
    }

    private func eventRow(_ event: DataModel.Event) -> some View {
        let isPast = EventPastStatus.isPast(
            event: event,
            at: today,
            forSpreadDate: spreadDataModel.spread.date,
            calendar: calendar
        )

        return EntryRowView(
            event: event,
            isEventPast: isPast,
            onEdit: { onEdit?(event) },
            onDelete: { onDelete?(event) }
        )
    }

    private func noteRow(_ note: DataModel.Note) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: nil, // TODO: SPRD-29 - Add migration destination label
            onMigrate: { onMigrate?(note) },
            onEdit: { onEdit?(note) },
            onDelete: { onDelete?(note) }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Entries", systemImage: "tray")
        } description: {
            Text("Add tasks, events, or notes to this spread.")
        }
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
        events: [DataModel.Event(title: "Day 5 event", startDate: day5)]
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
        events: [DataModel.Event(title: "An event", startDate: today)]
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

#Preview("All Entry Types") {
    let calendar = Calendar.current
    let today = Date()
    let spread = DataModel.Spread(period: .day, date: today, calendar: calendar)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
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
        events: [
            DataModel.Event(title: "Current event", startDate: today),
            DataModel.Event(title: "Past event", startDate: yesterday)
        ]
    )
    EntryListView(spreadDataModel: dataModel, calendar: calendar, today: today)
}
