//
//  StandardTaskAssignmentReconciler.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Standard implementation of `TaskAssignmentReconciler` using `ConventionalSpreadService`.
///
/// Finds the best spread for a task's preferred date/period and updates assignments to
/// reflect the result. When the task is complete, the destination assignment inherits
/// `.complete` status; otherwise it is set to `.open`.
@MainActor
struct StandardTaskAssignmentReconciler: TaskAssignmentReconciler {
    /// The calendar used for date normalization and spread matching.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread]
    ) {
        let destination = spreadService.findBestSpread(for: task, in: spreads)
        let destinationStatus = task.status == .complete ? DataModel.Task.Status.complete : task.status

        if let destination {
            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in task.assignments.indices where index != destinationIndex && task.assignments[index].status != .migrated {
                    task.assignments[index].status = .migrated
                }
                task.assignments[destinationIndex].status = destinationStatus
            } else {
                migrateActiveAssignmentsToHistory(task)
                task.assignments.append(
                    TaskAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: destinationStatus
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(task)
        }
    }

    /// Marks all non-migrated assignments on the task as `.migrated`.
    ///
    /// Used to archive the task's history before appending a new active assignment.
    private func migrateActiveAssignmentsToHistory(_ task: DataModel.Task) {
        for index in task.assignments.indices where task.assignments[index].status != .migrated {
            task.assignments[index].status = .migrated
        }
    }
}
