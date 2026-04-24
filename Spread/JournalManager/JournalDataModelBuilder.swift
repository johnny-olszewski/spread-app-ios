import Foundation

/// Builds a `JournalDataModel` from the raw spread and entry collections.
///
/// Two strategies exist — one for each BuJo mode:
/// - **Conventional**: Organizes data around explicitly created spreads. Each entry
///   appears on a spread only when it has a matching assignment.
/// - **Traditional**: Derives virtual spreads from the entries' preferred dates. No
///   explicit spread records are required.
///
/// `JournalManager` uses the active builder for both full rebuilds and targeted
/// spread/surface patching after mutations.
protocol JournalDataModelBuilder {
    /// Constructs the nested period → date → `SpreadDataModel` dictionary.
    ///
    /// - Parameters:
    ///   - spreads: The currently existing spread records (ignored in traditional mode).
    ///   - tasks: All tasks in the journal.
    ///   - notes: All notes in the journal.
    ///   - events: All events in the journal.
    /// - Returns: A `JournalDataModel` keyed by `Period` and then by normalized `Date`.
    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel

    /// Builds one spread/surface model for the given key.
    ///
    /// Returns `nil` when the surface should be removed from the derived model under
    /// the current mode and data snapshot.
    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel?

    /// Returns the derived spread/surface keys that can be affected by this task in
    /// the current mode.
    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey>

    /// Returns the derived spread/surface keys that can be affected by this note in
    /// the current mode.
    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey>

    /// Returns the stable key representing an explicit spread if it participates in
    /// the current mode's data model, otherwise `nil`.
    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey?
}



/// Builds a `JournalDataModel` of virtual spreads derived from entry preferred dates.
///
/// In traditional mode no explicit spread records are created. Instead, the builder:
/// 1. Collects the distinct years, months, and days referenced by any task, note, or event.
/// 2. For each derived period/date pair, creates a virtual `SpreadDataModel` via
///    `TraditionalSpreadService`.
///
/// The resulting model mirrors the structure of conventional mode so that views can
/// navigate it identically regardless of the active BuJo mode.
struct TraditionalJournalDataModelBuilder: JournalDataModelBuilder {
    /// The calendar used for date normalization and period derivation.
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        var model: JournalDataModel = [:]
        let years = traditionalSpreadService.yearsWithEntries(tasks: tasks, notes: notes, events: events)
        var virtualSpreads: [(period: Period, date: Date)] = []

        for yearDate in years {
            virtualSpreads.append((.year, yearDate))
        }

        for yearDate in years {
            let months = traditionalSpreadService.monthsWithEntries(
                inYear: yearDate,
                tasks: tasks,
                notes: notes,
                events: events
            )
            for monthDate in months {
                virtualSpreads.append((.month, monthDate))
            }
        }

        let allMonths = years.flatMap {
            traditionalSpreadService.monthsWithEntries(
                inYear: $0,
                tasks: tasks,
                notes: notes,
                events: events
            )
        }

        for monthDate in allMonths {
            let days = traditionalSpreadService.daysWithEntries(
                inMonth: monthDate,
                tasks: tasks,
                notes: notes,
                events: events
            )
            for dayDate in days {
                virtualSpreads.append((.day, dayDate))
            }
        }

        for (period, date) in virtualSpreads {
            let normalizedDate = period.normalizeDate(date, calendar: calendar)
            let spreadData = traditionalSpreadService.virtualSpreadDataModel(
                period: period,
                date: normalizedDate,
                tasks: tasks,
                notes: notes,
                events: events
            )

            if model[period] == nil {
                model[period] = [:]
            }
            model[period]?[normalizedDate] = spreadData
        }

        return model
    }

    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel? {
        guard key.period != .multiday else { return nil }

        let spreadData = traditionalSpreadService.virtualSpreadDataModel(
            period: key.period,
            date: key.date,
            tasks: tasks,
            notes: notes,
            events: events
        )

        guard !spreadData.tasks.isEmpty || !spreadData.notes.isEmpty || !spreadData.events.isEmpty else {
            return nil
        }

        return spreadData
    }

    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        guard task.hasPreferredAssignment, task.period != .multiday else { return [] }
        return [SpreadDataModelKey(period: task.period, date: task.date, calendar: calendar)]
    }

    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        guard note.period != .multiday else { return [] }
        return [SpreadDataModelKey(period: note.period, date: note.date, calendar: calendar)]
    }

    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey? {
        let key = SpreadDataModelKey(spread: spread, calendar: calendar)
        return buildSpreadDataModel(for: key, spreads: spreads, tasks: tasks, notes: notes, events: events) == nil ? nil : key
    }
}
