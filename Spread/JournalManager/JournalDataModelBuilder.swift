import Foundation

/// Builds a `JournalDataModel` from the raw spread and entry collections.
///
/// Two strategies exist — one for each BuJo mode:
/// - **Conventional**: Organizes data around explicitly created spreads. Each entry
///   appears on a spread only when it has a matching assignment.
/// - **Traditional**: Derives virtual spreads from the entries' preferred dates. No
///   explicit spread records are required.
///
/// `JournalManager` calls the active builder after every data load or mutation and
/// replaces `dataModel` with the result.
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
}

/// Builds a `JournalDataModel` from explicitly created spreads in conventional mode.
///
/// For each existing spread, the builder collects:
/// - Tasks/notes that have an assignment matching the spread's period and date.
/// - Events whose date range overlaps the spread (via `ConventionalSpreadService`).
/// - Multiday spreads collect tasks and notes whose preferred date falls within the date range.
struct ConventionalJournalDataModelBuilder: JournalDataModelBuilder {
    /// The calendar used for date normalization and event overlap checks.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        var model: JournalDataModel = [:]

        for spread in spreads {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
            var spreadData = SpreadDataModel(spread: spread)
            spreadData.tasks = tasksForSpread(spread, tasks: tasks)
            spreadData.notes = notesForSpread(spread, notes: notes)
            spreadData.events = events.filter { spreadService.eventAppearsOnSpread($0, spread: spread) }

            if model[spread.period] == nil {
                model[spread.period] = [:]
            }
            model[spread.period]?[normalizedDate] = spreadData
        }

        return model
    }

    private func tasksForSpread(_ spread: DataModel.Spread, tasks: [DataModel.Task]) -> [DataModel.Task] {
        if spread.period == .multiday {
            return tasks.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return tasks.filter { hasSpreadAssociation($0, for: spread) }
    }

    private func notesForSpread(_ spread: DataModel.Spread, notes: [DataModel.Note]) -> [DataModel.Note] {
        if spread.period == .multiday {
            return notes.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    private func entryDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    private func hasSpreadAssociation(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    private func hasSpreadAssociation(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }
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
}
