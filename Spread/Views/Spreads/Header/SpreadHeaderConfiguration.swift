import Foundation

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

    /// The reference date for live dynamic naming.
    let today: Date

    /// The user's first day of week preference.
    let firstWeekday: FirstWeekday

    /// Whether persisted personalization should affect the displayed title.
    let allowsPersonalization: Bool

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
        today: Date = .now,
        firstWeekday: FirstWeekday = .systemDefault,
        allowsPersonalization: Bool = false,
        taskCount: Int = 0,
        eventCount: Int = 0,
        noteCount: Int = 0
    ) {
        self.spread = spread
        self.calendar = calendar
        self.today = today
        self.firstWeekday = firstWeekday
        self.allowsPersonalization = allowsPersonalization
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
    init(
        spreadDataModel: SpreadDataModel,
        calendar: Calendar,
        today: Date = .now,
        firstWeekday: FirstWeekday = .systemDefault,
        allowsPersonalization: Bool = false
    ) {
        self.spread = spreadDataModel.spread
        self.calendar = calendar
        self.today = today
        self.firstWeekday = firstWeekday
        self.allowsPersonalization = allowsPersonalization
        self.taskCount = spreadDataModel.tasks.count
        self.eventCount = spreadDataModel.events.count
        self.noteCount = spreadDataModel.notes.count
    }

    // MARK: - Title Formatting

    /// The formatted title for the spread header.
    ///
    /// Format varies by period:
    /// - Year: "2026"
    /// - Month: "January"
    /// - Day: "January 5, 2026"
    /// - Multiday: "6 Jan - 12 Jan"
    var title: String {
        displayName.primary
    }

    var subtitle: String? {
        displayName.secondaryForHeader
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

    // MARK: - Private Formatting

    private var displayName: SpreadDisplayName {
        SpreadDisplayNameFormatter(
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday
        )
        .display(for: spread, allowsPersonalization: allowsPersonalization)
    }
}
