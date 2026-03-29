import SwiftUI

/// A collapsible section showing entries that were migrated FROM this spread.
///
/// Displays at the bottom of a spread's entry list. Shows grayed-out rows with
/// migration destination info and supports expansion/collapse with animation.
///
/// Includes both migrated tasks and migrated notes. Each row shows the entry
/// title and the spread it was migrated to.
struct MigratedEntriesSection: View {

    // MARK: - Properties

    /// The spread these entries were migrated from.
    let spread: DataModel.Spread

    /// Tasks that were migrated from this spread.
    let migratedTasks: [DataModel.Task]

    /// Notes that were migrated from this spread.
    let migratedNotes: [DataModel.Note]

    /// The calendar for date formatting.
    let calendar: Calendar

    /// Callback when an entry is tapped for editing.
    var onEdit: ((any Entry) -> Void)?

    /// Whether the section is expanded.
    @State private var isExpanded = false

    // MARK: - Computed Properties

    /// Total count of migrated entries.
    private var totalCount: Int {
        migratedTasks.count + migratedNotes.count
    }

    /// Formatter for computing migration destinations.
    private var formatter: MigrationDestinationFormatter {
        MigrationDestinationFormatter(calendar: calendar)
    }

    // MARK: - Body

    var body: some View {
        if totalCount > 0 {
            Section {
                if isExpanded {
                    ForEach(migratedTasks, id: \.id) { task in
                        migratedTaskRow(task)
                    }
                    ForEach(migratedNotes, id: \.id) { note in
                        migratedNoteRow(note)
                    }
                }
            } header: {
                sectionHeader
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(.secondary)

                Text("Migrated (\(totalCount))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.SpreadContent.migratedSectionHeader)
    }

    // MARK: - Rows

    private func migratedTaskRow(_ task: DataModel.Task) -> some View {
        EntryRowView(
            task: task,
            migrationDestination: formatter.destination(for: task, from: spread),
            onEdit: { onEdit?(task) },
            opensEditOnTap: true
        )
        .listRowBackground(Color.clear)
    }

    private func migratedNoteRow(_ note: DataModel.Note) -> some View {
        EntryRowView(
            note: note,
            migrationDestination: formatter.destination(for: note, from: spread),
            onEdit: { onEdit?(note) }
        )
        .listRowBackground(Color.clear)
    }
}

// MARK: - Preview

#Preview("Migrated Tasks") {
    let calendar = Calendar.current
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
    let spread = DataModel.Spread(period: .month, date: spreadDate, calendar: calendar)

    let task1 = DataModel.Task(
        title: "Review proposal",
        date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!,
        period: .day,
        status: .migrated
    )
    task1.assignments = [
        TaskAssignment(period: .month, date: spreadDate, status: .migrated),
        TaskAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 5))!, status: .open)
    ]

    let task2 = DataModel.Task(
        title: "Call client",
        date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!,
        period: .day,
        status: .migrated
    )
    task2.assignments = [
        TaskAssignment(period: .month, date: spreadDate, status: .migrated),
        TaskAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 10))!, status: .open)
    ]

    return List {
        MigratedEntriesSection(
            spread: spread,
            migratedTasks: [task1, task2],
            migratedNotes: [],
            calendar: calendar
        )
    }
}

#Preview("Mixed Migrated Entries") {
    let calendar = Calendar.current
    let spreadDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
    let spread = DataModel.Spread(period: .month, date: spreadDate, calendar: calendar)

    let task = DataModel.Task(
        title: "Follow up meeting",
        date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!,
        period: .day,
        status: .migrated
    )
    task.assignments = [
        TaskAssignment(period: .month, date: spreadDate, status: .migrated),
        TaskAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!, status: .open)
    ]

    let note = DataModel.Note(
        title: "Project notes",
        date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!,
        period: .day,
        status: .migrated
    )
    note.assignments = [
        NoteAssignment(period: .month, date: spreadDate, status: .migrated),
        NoteAssignment(period: .day, date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!, status: .active)
    ]

    return List {
        MigratedEntriesSection(
            spread: spread,
            migratedTasks: [task],
            migratedNotes: [note],
            calendar: calendar
        )
    }
}

#Preview("Empty - No Migrated Entries") {
    List {
        MigratedEntriesSection(
            spread: DataModel.Spread(period: .month, date: .now, calendar: .current),
            migratedTasks: [],
            migratedNotes: [],
            calendar: .current
        )
    }
}
