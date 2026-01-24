import class Foundation.DateFormatter
import struct Foundation.Calendar
import struct Foundation.Date

/// Configuration for displaying spread header information.
///
/// Encapsulates the logic for formatting spread titles and entry counts
/// based on the spread's period type. Separates presentation logic from
/// the view for testability.
struct SpreadHeaderConfiguration {

    // MARK: - Properties

    /// The spread being displayed.
    let spread: DataModel.Spread

    /// The calendar for date formatting.
    let calendar: Calendar

    /// The number of tasks on this spread.
    let taskCount: Int

    /// The number of events on this spread.
    let eventCount: Int

    /// The number of notes on this spread.
    let noteCount: Int

    // MARK: - Initialization

    /// Creates a configuration for a spread with explicit counts.
    ///
    /// - Parameters:
    ///   - spread: The spread to display.
    ///   - calendar: The calendar for date formatting.
    ///   - taskCount: The number of tasks (defaults to 0).
    ///   - eventCount: The number of events (defaults to 0).
    ///   - noteCount: The number of notes (defaults to 0).
    init(
        spread: DataModel.Spread,
        calendar: Calendar,
        taskCount: Int = 0,
        eventCount: Int = 0,
        noteCount: Int = 0
    ) {
        self.spread = spread
        self.calendar = calendar
        self.taskCount = taskCount
        self.eventCount = eventCount
        self.noteCount = noteCount
    }

    /// Creates a configuration from a SpreadDataModel.
    ///
    /// Extracts entry counts from the data model.
    ///
    /// - Parameters:
    ///   - spreadDataModel: The spread data model containing entries.
    ///   - calendar: The calendar for date formatting.
    init(spreadDataModel: SpreadDataModel, calendar: Calendar) {
        self.spread = spreadDataModel.spread
        self.calendar = calendar
        self.taskCount = spreadDataModel.tasks.count
        self.eventCount = spreadDataModel.events.count
        self.noteCount = spreadDataModel.notes.count
    }

    // MARK: - Title Formatting

    /// The formatted title for the spread header.
    ///
    /// Format varies by period:
    /// - Year: "2026"
    /// - Month: "January 2026"
    /// - Day: "January 5, 2026"
    /// - Multiday: "Jan 6 - Jan 12, 2026" or "Dec 28, 2025 - Jan 3, 2026"
    var title: String {
        switch spread.period {
        case .year:
            return formatYearTitle()
        case .month:
            return formatMonthTitle()
        case .day:
            return formatDayTitle()
        case .multiday:
            return formatMultidayTitle()
        }
    }

    // MARK: - Entry Counts

    /// The total number of entries across all types.
    var totalCount: Int {
        taskCount + noteCount
    }

    /// A summary text describing the entry counts.
    ///
    /// Examples:
    /// - "No entries"
    /// - "1 task"
    /// - "5 tasks"
    /// - "3 tasks, 1 note"
    var countSummaryText: String {
        if totalCount == 0 {
            return "No entries"
        }

        var parts: [String] = []

        if taskCount > 0 {
            parts.append(taskCount == 1 ? "1 task" : "\(taskCount) tasks")
        }

        if noteCount > 0 {
            parts.append(noteCount == 1 ? "1 note" : "\(noteCount) notes")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Private Formatting Methods

    private func formatYearTitle() -> String {
        String(calendar.component(.year, from: spread.date))
    }

    private func formatMonthTitle() -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: spread.date)
    }

    private func formatDayTitle() -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        return formatter.string(from: spread.date)
    }

    private func formatMultidayTitle() -> String {
        guard let startDate = spread.startDate, let endDate = spread.endDate else {
            return "Multiday"
        }

        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        if startYear == endYear {
            // Same year: "Jan 6 - Jan 12, 2026"
            let startFormatter = DateFormatter()
            startFormatter.calendar = calendar
            startFormatter.timeZone = calendar.timeZone
            startFormatter.dateFormat = "MMM d"

            let endFormatter = DateFormatter()
            endFormatter.calendar = calendar
            endFormatter.timeZone = calendar.timeZone
            endFormatter.dateFormat = "MMM d, yyyy"

            return "\(startFormatter.string(from: startDate)) - \(endFormatter.string(from: endDate))"
        } else {
            // Different years: "Dec 28, 2025 - Jan 3, 2026"
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "MMM d, yyyy"

            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
    }
}
