import struct Foundation.Date

/// Data model for a single spread's content.
///
/// Contains the spread and its associated entries. Used to organize
/// journal data by period and date for efficient access.
struct SpreadDataModel: Sendable {
    /// The spread this data model represents.
    let spread: DataModel.Spread

    /// Tasks assigned to this spread.
    ///
    /// Only includes tasks with assignments matching this spread's period and date.
    /// Populated by JournalManager during data loading.
    var tasks: [DataModel.Task]

    /// Notes assigned to this spread.
    ///
    /// Only includes notes with assignments matching this spread's period and date.
    /// Populated by JournalManager during data loading.
    var notes: [DataModel.Note]

    /// Events visible on this spread.
    ///
    /// Includes events whose date range overlaps with this spread.
    /// Computed based on event visibility rules, not assignments.
    var events: [DataModel.Event]

    /// Creates an empty spread data model.
    ///
    /// - Parameter spread: The spread this data model represents.
    init(spread: DataModel.Spread) {
        self.spread = spread
        self.tasks = []
        self.notes = []
        self.events = []
    }

    /// Creates a spread data model with entries.
    ///
    /// - Parameters:
    ///   - spread: The spread this data model represents.
    ///   - tasks: Tasks assigned to this spread.
    ///   - notes: Notes assigned to this spread.
    ///   - events: Events visible on this spread.
    init(
        spread: DataModel.Spread,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) {
        self.spread = spread
        self.tasks = tasks
        self.notes = notes
        self.events = events
    }
}

/// The journal data model organized by period and date.
///
/// Provides efficient access to spread data by period (year/month/day/multiday)
/// and normalized date. Used by JournalManager and views for data access.
typealias JournalDataModel = [Period: [Date: SpreadDataModel]]
