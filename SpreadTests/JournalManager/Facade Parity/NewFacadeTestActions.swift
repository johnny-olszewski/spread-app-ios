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
}
