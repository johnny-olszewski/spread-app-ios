//
//  StandardTaskMutationCoordinator.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Standard implementation of `TaskMutationCoordinator`.
///
/// Uses `TaskAssignmentReconciler` for spread assignment logic.
/// All persistence goes through `taskRepository`.
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

    func createTask(
        title: String,
        body: String? = nil,
        priority: DataModel.Task.Priority = .none,
        dueDate: Date? = nil,
        date: Date?,
        period: Period?,
        preferredSpreadID: UUID? = nil,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        let normalizedDate = date.map { period?.normalizeDate($0, calendar: calendar) ?? $0 }
        let task = DataModel.Task(
            title: title,
            body: body,
            priority: priority,
            dueDate: dueDate?.startOfDay(calendar: calendar),
            createdDate: .now,
            date: normalizedDate,
            period: period,
            status: .open,
            assignments: []
        )

        if normalizedDate != nil {
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
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult {
        task.date = nil
        task.period = nil
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

}
