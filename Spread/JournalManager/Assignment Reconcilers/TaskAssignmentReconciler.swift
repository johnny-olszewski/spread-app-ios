//
//  TaskAssignmentReconciler.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Reconciles a task's spread assignment against the set of currently existing spreads.
///
/// Called after a task is created or its preferred date/period changes. The reconciler
/// inspects the task's `date` and `period`, finds the best matching conventional spread
/// using `ConventionalSpreadService`, and updates `task.assignments` in-place so that
/// exactly one assignment is active (or none if no spread matches).
///
/// Assignment mutation rules:
/// - If the best spread already has an assignment, it is promoted to the current status
///   and all other non-migrated assignments are marked `.migrated`.
/// - If the best spread has no existing assignment, all non-migrated assignments are marked
///   `.migrated` and a new assignment for the destination is appended.
/// - If no matching spread exists, all non-migrated assignments are marked `.migrated`
///   (the task lands in the Inbox).
@MainActor
protocol TaskAssignmentReconciler {
    /// Updates the task's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `task.assignments` in-place. Does not persist; callers must save the task afterward.
    ///
    /// - Parameters:
    ///   - task: The task whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    ///   - preferredSpreadID: Explicit multiday spread identity when the user
    ///     directly selected one.
    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID?
    )
}
