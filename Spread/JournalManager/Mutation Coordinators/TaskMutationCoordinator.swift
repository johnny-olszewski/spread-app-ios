//
//  TaskMutationCoordinator.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Coordinates task creation and preferred-date mutation workflows.
///
/// Encapsulates the rules for normalizing dates, reconciling spread assignments, and
/// persisting changes. Methods return the updated task plus the refreshed task list
/// so callers can update in-memory state and derive targeted mutation scope.
@MainActor
protocol TaskMutationCoordinator {
    /// Creates a new open task and assigns it to the best matching spread.
    ///
    /// The date is normalized to the period before the task is created. Assignment
    /// reconciliation runs immediately so the task lands on the correct spread
    /// (or Inbox if none matches).
    ///
    /// - Parameters:
    ///   - title: The task title.
    ///   - date: The user's chosen date.
    ///   - period: The user's chosen period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The new task and the refreshed full task list.
    /// - Throws: Repository errors if persistence fails.
    func createTask(
        title: String,
        body: String?,
        priority: DataModel.Task.Priority,
        dueDate: Date?,
        date: Date,
        period: Period,
        preferredSpreadID: UUID?,
        hasPreferredAssignment: Bool,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult

    /// Updates a task's preferred date and period, then re-reconciles its spread assignment.
    ///
    /// Normalizes the new date to the period, updates the task's `date` and `period`
    /// properties, runs assignment reconciliation, and persists the change.
    ///
    /// - Parameters:
    ///   - task: The task to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The updated task and refreshed full task list.
    /// - Throws: Repository errors if persistence fails.
    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID?,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult

    /// Clears a task's preferred assignment and migrates any live assignment history.
    func clearTaskPreferredAssignment(
        _ task: DataModel.Task,
        fallbackDate: Date,
        fallbackPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult

    /// Migrates a task to a new preferred date/period in traditional mode.
    ///
    /// Clears all existing assignments, updates the task's `date` and `period`, then
    /// attempts to create a single new assignment on the nearest matching conventional
    /// spread. Unlike conventional migration, this does not mark any source assignment
    /// as `.migrated` — the task's full assignment history is replaced.
    ///
    /// - Parameters:
    ///   - task: The task to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used to find the best conventional spread.
    /// - Returns: The updated task and refreshed full task list.
    /// - Throws: `MigrationError.taskCancelled` if the task is cancelled; repository errors
    ///   if persistence fails.
    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskListMutationResult
}
