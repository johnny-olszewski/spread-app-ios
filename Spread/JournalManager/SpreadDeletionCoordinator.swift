import Foundation
import OSLog

/// Workflow coordinator for spread deletion: reassigns every task/note's assignment on the
/// deleted spread to a parent spread (day→month→year walk) or Inbox, then deletes the spread.
/// Entries are never deleted, only their assignments are mutated.
///
/// Concrete, no protocol declaration, no "Standard" naming — per
/// `Documentation/Specs/JournalManager.md`'s "Decision: Drop protocol-per-logic-seam;
/// protocols are a repository-only boundary." Depends on `SpreadRepository`/
/// `TaskRepository`/`NoteRepository` (the genuine substitution boundary) and a plain
/// `Calendar` — not `JournalRuleEngine`, since this mechanic never calls a rule-engine
/// reconciliation method, only `Assignment.matches(spread:calendar:)` and
/// `SpreadService(calendar:).findBestSpread`.
///
/// Distinct dependency shape (three repositories at once) and infrequent lifecycle (spread
/// deletion, not routine entry mutation) versus `TaskCoordinator`/`NoteCoordinator` (SPRD-255),
/// which is why this stays its own type rather than folding into either.
///
/// Like `TaskCoordinator`/`NoteCoordinator`, this type does not patch `JournalManager`'s
/// incremental index or read `JournalManager.spreads`/`.tasks`/`.notes` directly — callers
/// pass those in per call and use the returned mutated entities to upsert their own observed
/// state afterward.
///
/// Used by `JournalManager.deleteSpread`, which delegates to this type and then patches its
/// own incremental index via `upsertTask`/`upsertNote`/`removeSpread`.
@MainActor
struct SpreadDeletionCoordinator {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "SpreadDeletionCoordinator")

    /// Repository for spread persistence.
    let spreadRepository: any SpreadRepository

    /// Repository for task persistence and sync-outbox diffing.
    let taskRepository: any TaskRepository

    /// Repository for note persistence and sync-outbox diffing.
    let noteRepository: any NoteRepository

    /// Calendar used for assignment matching and parent-spread lookup.
    let calendar: Calendar

    /// Deletes `spread`, reassigning every task/note currently or historically assigned to it
    /// to a parent spread (day→month→year) or Inbox if none exists.
    ///
    /// Scoped to non-multiday deletion's parent-hierarchy walk — multiday-spread deletion
    /// falls back to each entry's own best-matching non-multiday spread (no parent-hierarchy
    /// concept applies to a custom range).
    ///
    /// - Returns: The tasks and notes that were actually reassigned, for the caller to upsert
    ///   into its own observed state. Entries with no assignment on `spread` are untouched and
    ///   not included.
    @discardableResult
    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> (mutatedTasks: [DataModel.Task], mutatedNotes: [DataModel.Note]) {
        let parentSpread = spread.period == .multiday ? nil : findParentSpread(for: spread, in: spreads)
        var mutatedTasks: [DataModel.Task] = []
        var mutatedNotes: [DataModel.Note] = []

        for task in tasks {
            let previousTaskAssignments = task.currentAssignments + task.migrationHistory

            let sourceAssignment: Assignment
            if let currentIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = task.currentAssignments.remove(at: currentIndex)
            } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = task.migrationHistory.remove(at: historyIndex)
            } else {
                continue
            }
            let preservedStatus = sourceAssignment.status

            // The source assignment always ends up migrated history, whether or not a
            // replacement is found — deleting its spread invalidates it as a current
            // pointer either way.
            var sourceAsHistory = sourceAssignment
            sourceAsHistory.status = .migrated
            task.migrationHistory.append(sourceAsHistory)

            if let replacement = replacementSpread(for: task, deleting: spread, parentSpread: parentSpread, spreads: spreads) {
                if let destinationIndex = task.currentAssignments.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    task.currentAssignments[destinationIndex].status = preservedStatus
                } else if let historyIndex = task.migrationHistory.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    if preservedStatus == .migrated {
                        task.migrationHistory[historyIndex].status = preservedStatus
                    } else {
                        var revived = task.migrationHistory.remove(at: historyIndex)
                        revived.status = preservedStatus
                        task.currentAssignments.append(revived)
                    }
                } else {
                    let newAssignment = Assignment(period: replacement.period, date: replacement.date, status: preservedStatus)
                    if preservedStatus == .migrated {
                        task.migrationHistory.append(newAssignment)
                    } else {
                        task.currentAssignments.append(newAssignment)
                    }
                }
            }

            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousTaskAssignments, previousTagIDs: task.tags.map(\.id))
            )
            mutatedTasks.append(task)
        }

        for note in notes {
            let previousNoteAssignments = note.currentAssignments + note.migrationHistory

            let sourceAssignment: Assignment
            if let currentIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = note.currentAssignments.remove(at: currentIndex)
            } else if let historyIndex = note.migrationHistory.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) {
                sourceAssignment = note.migrationHistory.remove(at: historyIndex)
            } else {
                continue
            }
            let preservedStatus = sourceAssignment.status

            // The source assignment always ends up migrated history, whether or not a
            // replacement is found — deleting its spread invalidates it as a current
            // pointer either way.
            var sourceAsHistory = sourceAssignment
            sourceAsHistory.status = .migrated
            note.migrationHistory.append(sourceAsHistory)

            if let replacement = replacementSpread(for: note, deleting: spread, parentSpread: parentSpread, spreads: spreads) {
                if let destinationIndex = note.currentAssignments.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    note.currentAssignments[destinationIndex].status = preservedStatus
                } else if let historyIndex = note.migrationHistory.firstIndex(where: { $0.matches(spread: replacement, calendar: calendar) }) {
                    if preservedStatus == .migrated {
                        note.migrationHistory[historyIndex].status = preservedStatus
                    } else {
                        var revived = note.migrationHistory.remove(at: historyIndex)
                        revived.status = preservedStatus
                        note.currentAssignments.append(revived)
                    }
                } else {
                    let newAssignment = Assignment(period: replacement.period, date: replacement.date, status: preservedStatus)
                    if preservedStatus == .migrated {
                        note.migrationHistory.append(newAssignment)
                    } else {
                        note.currentAssignments.append(newAssignment)
                    }
                }
            }

            try await noteRepository.save(
                note,
                change: EntityChange(isNew: false, previousAssignments: previousNoteAssignments, previousTagIDs: note.tags.map(\.id))
            )
            mutatedNotes.append(note)
        }

        try await spreadRepository.delete(spread)

        Self.logger.debug("Spread deleted: \(spread.period.rawValue, privacy: .public) spread \(spread.id, privacy: .public)")

        return (mutatedTasks, mutatedNotes)
    }

    // MARK: - Private Helpers

    /// Mirrors the legacy `StandardSpreadDeletionPlanner.replacementSpread`: for a
    /// non-multiday deletion, the replacement is simply the parent spread already found by
    /// `findParentSpread`. For a multiday deletion, there's no parent-hierarchy concept for
    /// a custom range — instead, fall back to whatever non-multiday spread best matches the
    /// task's own preferred date/period (excluding the spread being deleted), the same way
    /// the legacy planner did.
    private func replacementSpread(
        for task: DataModel.Task,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        guard spread.period == .multiday else { return parentSpread }
        guard let taskDate = task.date else { return nil }
        let fallbackPeriod: Period = task.period == .multiday ? .month : (task.period ?? .day)
        return SpreadService(calendar: calendar).findBestSpread(
            preferredDate: taskDate,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }

    /// Mirrors the legacy `StandardSpreadDeletionPlanner.replacementSpread` for notes.
    private func replacementSpread(
        for note: DataModel.Note,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?,
        spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        guard spread.period == .multiday else { return parentSpread }
        guard let noteDate = note.date else { return nil }
        let fallbackPeriod: Period = note.period == .multiday ? .month : note.period
        return SpreadService(calendar: calendar).findBestSpread(
            preferredDate: noteDate,
            preferredPeriod: fallbackPeriod,
            in: spreads.filter { $0.id != spread.id && $0.period != .multiday }
        )
    }

    private func findParentSpread(for spread: DataModel.Spread, in spreads: [DataModel.Spread]) -> DataModel.Spread? {
        var currentPeriod = spread.period.parentPeriod
        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(spread.date, calendar: calendar)
            if let parent = spreads.first(where: {
                $0.period == period && $0.period.normalizeDate($0.date, calendar: calendar) == normalizedDate
            }) {
                return parent
            }
            currentPeriod = period.parentPeriod
        }
        return nil
    }
}
