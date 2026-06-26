import Foundation
import OSLog

/// Workflow coordinator for task creation, metadata updates, and migration.
///
/// Concrete, no protocol declaration, no "Standard" naming — per
/// `Documentation/Specs/JournalManager.md`'s "Decision: Drop protocol-per-logic-seam;
/// protocols are a repository-only boundary." Depends only on `TaskRepository` (the
/// genuine substitution boundary) and `JournalRuleEngine` (SPRD-248, for assignment
/// reconciliation and migration mechanics) — not on `JournalManager` itself.
///
/// Unlike `JournalRuleEngine`, this type performs repository writes; that is its entire
/// purpose, per the spec's distinction between rule engines (pure) and workflow
/// coordinators (repository effects). It does not patch `JournalManager`'s incremental
/// index/`dataModel` or read `JournalManager.spreads` directly — callers pass `spreads`
/// in per call and are responsible for upserting the returned/mutated task into their own
/// observed state afterward (`Task`/`Note` are reference types, so a caller already
/// holding the entity sees in-place mutations without a return value).
///
/// - TODO: [SPRD-255] Not yet called anywhere. `JournalManager`'s task CRUD/migration
///   methods (`addTask`, `updateTask*`, `clearTaskPreferredAssignment`, `deleteTask`,
///   `migrateTask`/`moveTask`/`migrateTasksBatch`) will delegate to this type in this
///   task's next increment, replacing their current inline bodies.
@MainActor
struct TaskCoordinator {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "TaskCoordinator")

    /// Repository for task persistence and sync-outbox diffing.
    let taskRepository: any TaskRepository

    /// Rule engine for assignment reconciliation and migration mechanics.
    let ruleEngine: JournalRuleEngine

    // MARK: - Creation

    /// Creates a new task with the specified parameters, reconciling its preferred
    /// assignment against `spreads`.
    @discardableResult
    func addTask(
        title: String,
        date: Date?,
        period: Period?,
        preferredSpreadID: UUID? = nil,
        body: String?,
        priority: DataModel.Task.Priority,
        dueDate: Date?,
        spreads: [DataModel.Spread]
    ) async throws -> DataModel.Task {
        let normalizedDate = date.map { period?.normalizeDate($0, calendar: ruleEngine.calendar) ?? $0 }
        let task = DataModel.Task(
            title: title,
            body: sanitizedBody(body),
            priority: priority,
            dueDate: dueDate?.startOfDay(calendar: ruleEngine.calendar),
            date: normalizedDate,
            period: period,
            status: .open,
            currentAssignments: []
        )

        if normalizedDate != nil {
            ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: preferredSpreadID)
        }

        try await taskRepository.save(task, change: EntityChange(isNew: true))

        if task.currentAssignments.isEmpty {
            Self.logger.debug("Task created: \(task.id, privacy: .public) '\(task.title, privacy: .public)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Task created: \(task.id, privacy: .public) '\(task.title, privacy: .public)' → \(task.period?.rawValue ?? "none", privacy: .public) spread")
        }

        return task
    }

    /// Creates a new task with metadata, list, and tag, reconciling its preferred
    /// assignment against `spreads`.
    @discardableResult
    func addTask(
        title: String,
        date: Date,
        period: Period,
        list: DataModel.List? = nil,
        tag: DataModel.Tag? = nil,
        spreads: [DataModel.Spread]
    ) async throws -> DataModel.Task {
        let task = try await addTask(
            title: title, date: date, period: period, body: nil, priority: .none, dueDate: nil, spreads: spreads
        )
        guard list != nil || tag != nil else { return task }
        if let list { task.list = list }
        if let tag { task.tags = [tag] }
        try await taskRepository.save(
            task,
            change: EntityChange(
                isNew: false,
                previousAssignments: task.currentAssignments + task.migrationHistory,
                previousTagIDs: []
            )
        )
        return task
    }

    // MARK: - Updates

    /// Updates a task's title.
    func updateTitle(_ task: DataModel.Task, newTitle: String) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.currentAssignments + task.migrationHistory,
            previousTagIDs: task.tags.map(\.id)
        )
        task.title = newTitle
        try await taskRepository.save(task, change: change)
    }

    /// Updates a task's status (excluding `.migrated`, which is only set by migration flows).
    func updateStatus(_ task: DataModel.Task, newStatus: EntryStatus) async throws {
        guard newStatus != .migrated else { throw TaskMutationError.manualMigratedStatusNotAllowed }
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.currentAssignments + task.migrationHistory,
            previousTagIDs: task.tags.map(\.id)
        )
        task.status = newStatus
        try await taskRepository.save(task, change: change)
    }

    /// Updates a task's preferred date and period, reconciling its spread assignment
    /// against `spreads`.
    func updateDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil,
        spreads: [DataModel.Spread]
    ) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.currentAssignments + task.migrationHistory,
            previousTagIDs: task.tags.map(\.id)
        )
        task.date = newPeriod.normalizeDate(newDate, calendar: ruleEngine.calendar)
        task.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: preferredSpreadID)
        try await taskRepository.save(task, change: change)
    }

    /// Updates independently mergeable task metadata.
    func updateMetadata(
        _ task: DataModel.Task,
        body: String?,
        priority: DataModel.Task.Priority,
        dueDate: Date?,
        list: DataModel.List? = nil,
        tags: [DataModel.Tag] = []
    ) async throws {
        let previousTagIDs = task.tags.map(\.id)
        let timestamp = Date.now
        let normalizedBody = sanitizedBody(body)
        let normalizedDueDate = dueDate?.startOfDay(calendar: ruleEngine.calendar)

        if task.body != normalizedBody {
            task.body = normalizedBody
            task.bodyUpdatedAt = timestamp
        }
        if task.priority != priority {
            task.priority = priority
            task.priorityUpdatedAt = timestamp
        }
        if task.dueDate != normalizedDueDate {
            task.dueDate = normalizedDueDate
            task.dueDateUpdatedAt = timestamp
        }
        if task.list?.id != list?.id {
            task.list = list
            task.listUpdatedAt = timestamp
        }
        if Set(previousTagIDs) != Set(tags.map(\.id)) {
            task.tags = tags
        }

        try await taskRepository.save(
            task,
            change: EntityChange(
                isNew: false,
                previousAssignments: task.currentAssignments + task.migrationHistory,
                previousTagIDs: previousTagIDs
            )
        )
    }

    /// Clears a task's preferred assignment, leaving it in Inbox until explicitly reassigned.
    func clearPreferredAssignment(_ task: DataModel.Task, spreads: [DataModel.Spread]) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: task.currentAssignments + task.migrationHistory,
            previousTagIDs: task.tags.map(\.id)
        )
        task.date = nil
        task.period = nil
        ruleEngine.reconcilePreferredAssignment(for: task, in: spreads, preferredSpreadID: nil)
        try await taskRepository.save(task, change: change)
    }

    // MARK: - Deletion

    /// Deletes a task from the repository.
    func delete(_ task: DataModel.Task) async throws {
        try await taskRepository.delete(task)
    }

    // MARK: - Migration

    /// Migrates a task from a source spread to a destination spread.
    func migrateTask(_ task: DataModel.Task, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        try await moveTask(
            task,
            from: .init(kind: .spread(
                id: source.id,
                period: source.period,
                date: source.period.normalizeDate(source.date, calendar: ruleEngine.calendar)
            )),
            to: destination
        )
    }

    /// Moves a task from either Inbox or a source spread into a destination spread.
    func moveTask(_ task: DataModel.Task, from sourceKey: TaskReviewSourceKey, to destination: DataModel.Spread) async throws {
        guard task.status != .cancelled else { throw MigrationError.taskCancelled }
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }
        let previousAssignments = task.currentAssignments + task.migrationHistory

        let sourceMatch: ((Assignment) -> Bool)?
        switch sourceKey.kind {
        case .inbox:
            sourceMatch = nil
        case .spread(let sourceSpreadID, let sourcePeriod, let sourceDate):
            guard task.currentAssignments.contains(where: {
                $0.matches(period: sourcePeriod, date: sourceDate, spreadID: sourceSpreadID, calendar: ruleEngine.calendar)
            }) else {
                throw MigrationError.noSourceAssignment
            }
            sourceMatch = { $0.matches(period: sourcePeriod, date: sourceDate, spreadID: sourceSpreadID, calendar: ruleEngine.calendar) }
        }

        ruleEngine.migrateAssignment(for: task, matchingSource: sourceMatch, to: destination, status: .open)
        task.status = .open

        try await taskRepository.save(
            task,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
        )
    }

    /// Migrates multiple tasks from one spread to another. Skips cancelled tasks silently.
    func migrateTasksBatch(_ tasks: [DataModel.Task], from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        guard !tasks.isEmpty else { return }
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }

        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard task.currentAssignments.contains(where: { $0.matches(spread: source, calendar: ruleEngine.calendar) }) else {
                continue
            }
            let previousAssignments = task.currentAssignments + task.migrationHistory

            ruleEngine.migrateAssignment(
                for: task,
                matchingSource: { $0.matches(spread: source, calendar: ruleEngine.calendar) },
                to: destination,
                status: .open
            )
            task.status = .open

            try await taskRepository.save(
                task,
                change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: task.tags.map(\.id))
            )
        }
    }

    // MARK: - Private Helpers

    private func sanitizedBody(_ body: String?) -> String? {
        guard let trimmed = body?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
