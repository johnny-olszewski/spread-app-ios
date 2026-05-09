//
//  StandardTaskMutationCoordinator.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Standard implementation of `TaskMutationCoordinator`.
///
/// Uses `TaskAssignmentReconciler` for spread assignment logic and `TraditionalSpreadService`
/// for traditional-mode migration. All persistence goes through `taskRepository`.
@MainActor
struct StandardTaskMutationCoordinator: TaskMutationCoordinator {
    /// The repository used to persist and retrieve tasks.
    let taskRepository: any TaskRepository
    /// Reconciler for updating task spread assignments after creation or date changes.
    let taskAssignmentReconciler: any TaskAssignmentReconciler
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter
    /// Calendar used for date normalization and service initialization.
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createTask(
        title: String,
        body: String? = nil,
        priority: DataModel.Task.Priority = .none,
        dueDate: Date? = nil,
        date: Date,
        period: Period,
        preferredSpreadID: UUID? = nil,
        hasPreferredAssignment: Bool = true,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let task = DataModel.Task(
            title: title,
            body: body,
            priority: priority,
            dueDate: dueDate?.startOfDay(calendar: calendar),
            createdDate: .now,
            date: normalizedDate,
            period: period,
            hasPreferredAssignment: hasPreferredAssignment,
            status: .open,
            assignments: []
        )

        if hasPreferredAssignment {
            taskAssignmentReconciler.reconcilePreferredAssignment(
                for: task,
                in: spreads,
                preferredSpreadID: preferredSpreadID
            )
        }
        try await taskRepository.save(task)
        return TaskListMutationResult(
            task: task,
            tasks: await taskRepository.getTasks(),
            mutation: JournalMutationResult(
                kind: .taskChanged(id: task.id),
                scope: .structural
            )
        )
    }

    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
        task.hasPreferredAssignment = true
        taskAssignmentReconciler.reconcilePreferredAssignment(
            for: task,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )
        try await taskRepository.save(task)
        return TaskListMutationResult(
            task: task,
            tasks: await taskRepository.getTasks(),
            mutation: JournalMutationResult(
                kind: .taskChanged(id: task.id),
                scope: .structural
            )
        )
    }

    func clearTaskPreferredAssignment(
        _ task: DataModel.Task,
        fallbackDate: Date,
        fallbackPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        task.date = fallbackPeriod.normalizeDate(fallbackDate, calendar: calendar)
        task.period = fallbackPeriod
        task.hasPreferredAssignment = false
        taskAssignmentReconciler.reconcilePreferredAssignment(
            for: task,
            in: spreads,
            preferredSpreadID: nil
        )
        try await taskRepository.save(task)
        return TaskListMutationResult(
            task: task,
            tasks: await taskRepository.getTasks(),
            mutation: JournalMutationResult(
                kind: .taskChanged(id: task.id),
                scope: .structural
            )
        )
    }

    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
        task.hasPreferredAssignment = true
        task.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            task.assignments.append(
                TaskAssignment(
                    period: bestSpread.period,
                    date: bestSpread.date,
                    status: task.status == .complete ? .complete : .open
                )
            )
        }

        try await taskRepository.save(task)
        logger.info("Traditional migration: task \(task.id) → \(newPeriod.rawValue) \(normalizedDate)")
        return TaskListMutationResult(
            task: task,
            tasks: await taskRepository.getTasks(),
            mutation: JournalMutationResult(
                kind: .taskChanged(id: task.id),
                scope: .structural
            )
        )
    }
}
