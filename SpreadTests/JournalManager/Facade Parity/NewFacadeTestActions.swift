import Foundation
@testable import Spread

/// Test-only orchestration glue for driving `JournalDataStore` through the same logical
/// operations `JournalManager`'s CRUD methods perform, for SPRD-250's parity suite.
///
/// `JournalDataStore` (SPRD-249) intentionally has no CRUD orchestration of its own — only
/// the low-level `upsertTask`/`removeTask`-style primitives — since that orchestration layer
/// (`TaskCoordinator`/`NoteCoordinator`) doesn't exist yet (SPRD-255). This type exists only
/// so parity tests can compare "call the legacy method" against "do the equivalent sequence
/// against the new facade" without duplicating that sequence in every test. It is not a
/// preview of `TaskCoordinator`'s eventual shape — it leans directly on `JournalRuleEngine`
/// (already proven identical to the legacy reconcilers in SPRD-248's own parity tests) and
/// the `ChangeAware*Repository` protocols, mirroring exactly what `StandardTaskMutationCoordinator`/
/// `StandardNoteMutationCoordinator` do today.
@MainActor
struct NewFacadeTestActions {
    let store: JournalDataStore
    let calendar: Calendar
    let ruleEngine: JournalRuleEngine
    let taskRepository: any ChangeAwareTaskRepository
    let noteRepository: any ChangeAwareNoteRepository

    // MARK: - Task CRUD

    @discardableResult
    func createTask(
        title: String,
        date: Date?,
        period: Period?,
        preferredSpreadID: UUID? = nil,
        body: String? = nil,
        priority: DataModel.Task.Priority = .none,
        dueDate: Date? = nil
    ) async throws -> DataModel.Task {
        let task = DataModel.Task(
            title: title,
            body: body,
            priority: priority,
            dueDate: dueDate,
            date: date,
            period: period,
            status: .open,
            assignments: []
        )

        if date != nil {
            ruleEngine.reconcilePreferredAssignment(for: task, in: store.spreads, preferredSpreadID: preferredSpreadID)
        }

        try await taskRepository.save(task, change: EntityChange(isNew: true))
        store.upsertTask(task)
        return task
    }

    func updateTaskTitle(_ task: DataModel.Task, newTitle: String) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.assignments,
            previousTagIDs: task.tags.map(\.id)
        )
        task.title = newTitle
        try await taskRepository.save(task, change: change)
        store.upsertTask(task)
    }

    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil
    ) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.assignments,
            previousTagIDs: task.tags.map(\.id)
        )
        task.date = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: task, in: store.spreads, preferredSpreadID: preferredSpreadID)
        try await taskRepository.save(task, change: change)
        store.upsertTask(task)
    }

    func clearTaskPreferredAssignment(_ task: DataModel.Task) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.assignments,
            previousTagIDs: task.tags.map(\.id)
        )
        task.date = nil
        task.period = nil
        ruleEngine.reconcilePreferredAssignment(for: task, in: store.spreads, preferredSpreadID: nil)
        try await taskRepository.save(task, change: change)
        store.upsertTask(task)
    }

    func deleteTask(_ task: DataModel.Task) async throws {
        try await taskRepository.delete(task)
        store.removeTask(id: task.id)
    }

    // MARK: - Note CRUD

    @discardableResult
    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        preferredSpreadID: UUID? = nil
    ) async throws -> DataModel.Note {
        let note = DataModel.Note(
            title: title,
            content: content,
            date: period.normalizeDate(date, calendar: calendar),
            period: period,
            assignments: []
        )

        ruleEngine.reconcilePreferredAssignment(for: note, in: store.spreads, preferredSpreadID: preferredSpreadID)

        try await noteRepository.save(note, change: EntityChange(isNew: true))
        store.upsertNote(note)
        return note
    }

    func updateNoteTitle(_ note: DataModel.Note, newTitle: String, newContent: String) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: note.assignments,
            previousTagIDs: note.tags.map(\.id)
        )
        note.title = newTitle
        note.content = newContent
        try await noteRepository.save(note, change: change)
        store.upsertNote(note)
    }

    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil
    ) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: note.assignments,
            previousTagIDs: note.tags.map(\.id)
        )
        note.date = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: note, in: store.spreads, preferredSpreadID: preferredSpreadID)
        try await noteRepository.save(note, change: change)
        store.upsertNote(note)
    }

    func deleteNote(_ note: DataModel.Note) async throws {
        try await noteRepository.delete(note)
        store.removeNote(id: note.id)
    }

    // MARK: - Spread Create/Delete

    let spreadRepository: any SpreadRepository

    /// Mirrors `JournalManager.createSpread`'s auto-migration pass: after creating the
    /// spread, every existing task/note is re-reconciled against it in case it's now their
    /// best destination (e.g. an Inbox-origin task whose preferred date matches).
    @discardableResult
    func createSpread(period: Period, date: Date) async throws -> DataModel.Spread {
        let spread = DataModel.Spread(period: period, date: date, calendar: calendar)
        try await spreadRepository.save(spread)
        store.upsertSpread(spread)

        guard period.canHaveTasksAssigned else { return spread }

        for task in store.tasks where task.date != nil && task.status != .cancelled && task.status != .migrated {
            let previousAssignments = task.assignments
            ruleEngine.reconcilePreferredAssignment(for: task, in: store.spreads, preferredSpreadID: nil)
            guard task.assignments != previousAssignments else { continue }
            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
            )
            store.upsertTask(task)
        }

        for note in store.notes where note.status != .migrated {
            let previousAssignments = note.assignments
            ruleEngine.reconcilePreferredAssignment(for: note, in: store.spreads, preferredSpreadID: nil)
            guard note.assignments != previousAssignments else { continue }
            try await noteRepository.save(
                note,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id))
            )
            store.upsertNote(note)
        }

        return spread
    }

    /// Mirrors `StandardSpreadDeletionPlanner`/`StandardSpreadDeletionCoordinator`'s
    /// day→month→year parent-hierarchy reassignment for the non-multiday case: each
    /// task/note assigned to the deleted spread either moves to the nearest existing
    /// ancestor spread (preserving its status) or falls back to Inbox.
    ///
    /// Scoped to non-multiday deletion — the legacy planner's multiday-deletion fallback
    /// (re-deriving each entry's best non-multiday spread via `SpreadService.findBestSpread`)
    /// is not replicated here; multiday assignment itself is covered separately.
    func deleteSpreadWithReassignment(_ spread: DataModel.Spread) async throws {
        precondition(spread.period != .multiday, "Multiday spread deletion reassignment is not covered by this harness")

        let parentSpread = findParentSpread(for: spread, in: store.spreads)

        for task in store.tasks {
            guard let sourceIndex = task.assignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) else {
                continue
            }
            let previousAssignments = task.assignments
            let preservedStatus = task.assignments[sourceIndex].status
            task.assignments[sourceIndex].status = .migrated
            if let parentSpread {
                if let destinationIndex = task.assignments.firstIndex(where: { $0.matches(spread: parentSpread, calendar: calendar) }) {
                    task.assignments[destinationIndex].status = preservedStatus
                } else {
                    task.assignments.append(
                        Assignment(period: parentSpread.period, date: parentSpread.date, status: preservedStatus)
                    )
                }
            }
            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
            )
            store.upsertTask(task)
        }

        for note in store.notes {
            guard let sourceIndex = note.assignments.firstIndex(where: { $0.matches(spread: spread, calendar: calendar) }) else {
                continue
            }
            let previousAssignments = note.assignments
            let preservedStatus = note.assignments[sourceIndex].status
            note.assignments[sourceIndex].status = .migrated
            if let parentSpread {
                if let destinationIndex = note.assignments.firstIndex(where: { $0.matches(spread: parentSpread, calendar: calendar) }) {
                    note.assignments[destinationIndex].status = preservedStatus
                } else {
                    note.assignments.append(
                        Assignment(period: parentSpread.period, date: parentSpread.date, status: preservedStatus)
                    )
                }
            }
            try await noteRepository.save(
                note,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id))
            )
            store.upsertNote(note)
        }

        try await spreadRepository.delete(spread)
        store.removeSpread(id: spread.id)
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

    // MARK: - Migration

    /// Mirrors `StandardTaskMigrationCoordinator.moveTask` for the spread-to-spread case
    /// (not the Inbox-origin case, which has no source assignment to migrate).
    func migrateTask(_ task: DataModel.Task, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        let previousAssignments = task.assignments
        guard let sourceIndex = task.assignments.firstIndex(where: { $0.matches(spread: source, calendar: calendar) }) else {
            return
        }
        task.assignments[sourceIndex].status = .migrated

        if let destinationIndex = task.assignments.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            task.assignments[destinationIndex].status = .open
        } else {
            task.assignments.append(
                Assignment(
                    period: destination.period,
                    date: destination.date,
                    spreadID: destination.period == .multiday ? destination.id : nil,
                    status: .open
                )
            )
        }
        task.status = .open

        try await taskRepository.save(
            task,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
        )
        store.upsertTask(task)
    }

    /// Mirrors `StandardTaskMigrationCoordinator.migrateTasksBatch`.
    func migrateTasksBatch(_ tasks: [DataModel.Task], from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard task.assignments.contains(where: { $0.matches(spread: source, calendar: calendar) }) else { continue }
            try await migrateTask(task, from: source, to: destination)
        }
    }

    /// Mirrors `StandardNoteMigrationCoordinator.migrateNote`.
    func migrateNote(_ note: DataModel.Note, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        let previousAssignments = note.assignments
        guard let sourceIndex = note.assignments.firstIndex(where: { $0.matches(spread: source, calendar: calendar) }) else {
            return
        }
        note.assignments[sourceIndex].status = .migrated

        if let destinationIndex = note.assignments.firstIndex(where: { $0.matches(spread: destination, calendar: calendar) }) {
            note.assignments[destinationIndex].status = .active
        } else {
            note.assignments.append(
                Assignment(
                    period: destination.period,
                    date: destination.date,
                    spreadID: destination.period == .multiday ? destination.id : nil,
                    status: .active
                )
            )
        }

        try await noteRepository.save(
            note,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id))
        )
        store.upsertNote(note)
    }
}
