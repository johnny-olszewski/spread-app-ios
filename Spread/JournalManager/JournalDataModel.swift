import Foundation

/// Stable identity for a single spread/surface inside `JournalDataModel`.
///
/// The key is period plus the period-normalized date used by `JournalDataModel`.
/// Multiday spreads use their stored anchor date, which is already normalized by
/// spread construction.
struct SpreadDataModelKey: Hashable, Sendable {
    let period: Period
    let date: Date

    init(period: Period, normalizedDate: Date) {
        self.period = period
        self.date = normalizedDate
    }

    init(period: Period, date: Date, calendar: Calendar) {
        self.period = period
        self.date = period.normalizeDate(date, calendar: calendar)
    }

    init(spread: DataModel.Spread, calendar: Calendar) {
        self.period = spread.period
        self.date = spread.period.normalizeDate(spread.date, calendar: calendar)
    }
}

/// Data model for a single spread's content.
///
/// Contains the spread and its associated entries. Used to organize
/// journal data by period and date for efficient access.
struct SpreadDataModel: Sendable {
    /// The spread this data model represents.
    let spread: DataModel.Spread

    /// Tasks associated with this spread.
    ///
    /// Year/month/day spreads include tasks with assignments matching this spread's period and date.
    /// Multiday spreads include tasks whose preferred date falls within the range.
    /// Populated by JournalManager during data loading.
    var tasks: [DataModel.Task]

    /// Notes associated with this spread.
    ///
    /// Year/month/day spreads include notes with assignments matching this spread's period and date.
    /// Multiday spreads include notes whose preferred date falls within the range.
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

extension JournalDataModel {
    subscript(key key: SpreadDataModelKey) -> SpreadDataModel? {
        get {
            self[key.period]?[key.date]
        }
        set {
            if let newValue {
                if self[key.period] == nil {
                    self[key.period] = [:]
                }
                self[key.period]?[key.date] = newValue
                return
            }

            self[key.period]?[key.date] = nil
            if self[key.period]?.isEmpty == true {
                self[key.period] = nil
            }
        }
    }

    func spreadKeys(containingTaskID id: UUID) -> Set<SpreadDataModelKey> {
        Set(spreadKeys.filter { key in
            self[key: key]?.tasks.contains(where: { $0.id == id }) == true
        })
    }

    func spreadKeys(containingNoteID id: UUID) -> Set<SpreadDataModelKey> {
        Set(spreadKeys.filter { key in
            self[key: key]?.notes.contains(where: { $0.id == id }) == true
        })
    }

    var spreadKeys: [SpreadDataModelKey] {
        flatMap { period, spreads in
            spreads.keys.map { SpreadDataModelKey(period: period, normalizedDate: $0) }
        }
    }
}
