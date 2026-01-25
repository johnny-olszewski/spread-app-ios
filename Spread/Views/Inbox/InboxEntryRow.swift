import SwiftUI
import class Foundation.DateFormatter
import struct Foundation.Calendar
import struct Foundation.Date

/// A row displaying an inbox entry with symbol, title, and preferred date.
///
/// Used in the inbox sheet to show unassigned tasks and notes.
/// Each row shows:
/// - Entry type symbol (task: solid circle, note: dash)
/// - Title
/// - Preferred date formatted for display
struct InboxEntryRow: View {

    // MARK: - Properties

    /// The entry to display.
    private let entry: any Entry

    /// The preferred date of the entry.
    private let preferredDate: Date

    /// The entry type for symbol display.
    private let entryType: EntryType

    /// The calendar for date formatting.
    private let calendar: Calendar

    // MARK: - Initialization

    /// Creates an inbox entry row for a task.
    ///
    /// - Parameters:
    ///   - task: The task to display.
    ///   - calendar: The calendar for date formatting.
    init(task: DataModel.Task, calendar: Calendar) {
        self.entry = task
        self.preferredDate = task.date
        self.entryType = .task
        self.calendar = calendar
    }

    /// Creates an inbox entry row for a note.
    ///
    /// - Parameters:
    ///   - note: The note to display.
    ///   - calendar: The calendar for date formatting.
    init(note: DataModel.Note, calendar: Calendar) {
        self.entry = note
        self.preferredDate = note.date
        self.entryType = .note
        self.calendar = calendar
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            StatusIcon(entryType: entryType)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Date Formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: preferredDate)
    }
}

// MARK: - Previews

#Preview("Task Row") {
    List {
        InboxEntryRow(
            task: DataModel.Task(title: "Buy groceries", date: .now),
            calendar: .current
        )
    }
}

#Preview("Note Row") {
    List {
        InboxEntryRow(
            note: DataModel.Note(title: "Meeting notes", date: .now),
            calendar: .current
        )
    }
}

#Preview("Multiple Entries") {
    List {
        Section("Tasks") {
            InboxEntryRow(
                task: DataModel.Task(title: "Call dentist", date: .now),
                calendar: .current
            )
            InboxEntryRow(
                task: DataModel.Task(title: "Submit report", date: .now),
                calendar: .current
            )
        }
        Section("Notes") {
            InboxEntryRow(
                note: DataModel.Note(title: "Project ideas", date: .now),
                calendar: .current
            )
        }
    }
}
