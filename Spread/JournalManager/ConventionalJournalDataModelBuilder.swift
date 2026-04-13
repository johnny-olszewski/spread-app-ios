//
//  ConventionalJournalDataModelBuilder.swift
//  Spread
//
//  Created by Johnny O on 4/12/26.
//


import Foundation

/// Builds a `JournalDataModel` from explicitly created spreads in conventional mode.
///
/// For each existing spread, the builder collects:
/// - Tasks/notes that have an assignment matching the spread's period and date.
/// - Events whose date range overlaps the spread (via `ConventionalSpreadService`).
/// - Multiday spreads collect tasks and notes whose preferred date falls within the date range.
struct ConventionalJournalDataModelBuilder: JournalDataModelBuilder {
    /// The calendar used for date normalization and event overlap checks.
    private let calendar: Calendar
    /// Service used to determine event-to-spread overlap in conventional mode.
    private let spreadService: ConventionalSpreadService
    
    /// Creates a builder configured with the given calendar.
    ///
    /// - Parameter calendar: The calendar used for date normalization and event overlap checks.
    init(calendar: Calendar) {
        self.calendar = calendar
        self.spreadService = ConventionalSpreadService(calendar: calendar)
    }

    /// Builds the journal data model by iterating over each explicit spread and collecting
    /// the tasks, notes, and events that belong to it.
    ///
    /// For standard-period spreads (year, month, day), entries are matched via their
    /// assignments. For multiday spreads, entries are matched when their preferred date
    /// falls within the spread's date range. Events are matched by date-range overlap.
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

    /// Returns the tasks that belong on the given spread.
    ///
    /// Multiday spreads match tasks whose preferred date falls within the spread's
    /// start/end range. All other periods match tasks that have an assignment for the
    /// spread's period and date.
    private func tasksForSpread(_ spread: DataModel.Spread, tasks: [DataModel.Task]) -> [DataModel.Task] {
        if spread.period == .multiday {
            return tasks.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return tasks.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Returns the notes that belong on the given spread.
    ///
    /// Multiday spreads match notes whose preferred date falls within the spread's
    /// start/end range. All other periods match notes that have an assignment for the
    /// spread's period and date.
    private func notesForSpread(_ spread: DataModel.Spread, notes: [DataModel.Note]) -> [DataModel.Note] {
        if spread.period == .multiday {
            return notes.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Checks whether a normalized entry date falls within a multiday spread's date range.
    ///
    /// Returns `false` if the spread is not a multiday spread or if its start/end dates
    /// are not set.
    private func entryDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    /// Returns `true` if the task has an assignment matching the spread's period and date.
    private func hasSpreadAssociation(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Returns `true` if the note has an assignment matching the spread's period and date.
    private func hasSpreadAssociation(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }
}
