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
/// - Tasks/notes whose current non-migrated assignment matches the spread's period and date.
/// - Events whose date range overlaps the spread (via `ConventionalSpreadService`).
/// - Multiday spreads collect tasks and notes whose current assignment resolves to that
///   explicit multiday spread.
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
    /// For every explicit spread, entries are matched via their current non-migrated
    /// assignments. Multiday spreads therefore only show entries explicitly assigned
    /// to that spread. Events are matched by date-range overlap.
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

    /// Rebuilds one explicit spread surface for scoped `JournalManager` patching.
    ///
    /// Returns `nil` only when the matching explicit spread no longer exists.
    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel? {
        guard let spread = spreads.first(where: { candidate in
            candidate.period == key.period &&
            candidate.period.normalizeDate(candidate.date, calendar: calendar) == key.date
        }) else {
            return nil
        }

        return SpreadDataModel(
            spread: spread,
            tasks: tasksForSpread(spread, tasks: tasks),
            notes: notesForSpread(spread, notes: notes),
            events: events.filter { spreadService.eventAppearsOnSpread($0, spread: spread) }
        )
    }

    /// Returns all conventional surfaces that can display the task.
    ///
    /// This includes explicit spreads backed by the task's current non-migrated assignments.
    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        let explicitKeys: [SpreadDataModelKey] = task.assignments.compactMap { assignment in
            guard assignment.status != .migrated else { return nil }
            if assignment.period == .multiday,
               let spreadID = assignment.spreadID,
               let spread = spreads.first(where: { $0.id == spreadID }) {
                return SpreadDataModelKey(spread: spread, calendar: calendar)
            }
            return SpreadDataModelKey(period: assignment.period, date: assignment.date, calendar: calendar)
        }
        return Set(explicitKeys)
    }

    /// Returns all conventional surfaces that can display the note.
    ///
    /// This includes explicit spreads backed by the note's current non-migrated assignments.
    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        let explicitKeys: [SpreadDataModelKey] = note.assignments.compactMap { assignment in
            guard assignment.status != .migrated else { return nil }
            if assignment.period == .multiday,
               let spreadID = assignment.spreadID,
               let spread = spreads.first(where: { $0.id == spreadID }) {
                return SpreadDataModelKey(spread: spread, calendar: calendar)
            }
            return SpreadDataModelKey(period: assignment.period, date: assignment.date, calendar: calendar)
        }
        return Set(explicitKeys)
    }

    /// Returns the canonical derived-model key for an explicit conventional spread.
    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey? {
        SpreadDataModelKey(spread: spread, calendar: calendar)
    }

    /// Returns the tasks that belong on the given spread.
    ///
    /// All periods match tasks that have a current non-migrated
    /// assignment for the spread's period and date.
    private func tasksForSpread(_ spread: DataModel.Spread, tasks: [DataModel.Task]) -> [DataModel.Task] {
        return tasks.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Returns the notes that belong on the given spread.
    ///
    /// All periods match notes that have a current non-migrated
    /// assignment for the spread's period and date.
    private func notesForSpread(_ spread: DataModel.Spread, notes: [DataModel.Note]) -> [DataModel.Note] {
        return notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    /// Returns `true` if the task has a current non-migrated assignment matching the spread.
    private func hasSpreadAssociation(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.status != .migrated &&
            assignment.matches(spread: spread, calendar: calendar)
        }
    }

    /// Returns `true` if the note has a current non-migrated assignment matching the spread.
    private func hasSpreadAssociation(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.status != .migrated &&
            assignment.matches(spread: spread, calendar: calendar)
        }
    }
}
