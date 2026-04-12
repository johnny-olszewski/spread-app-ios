import Foundation

@MainActor
protocol TaskAssignmentReconciler {
    func reconcilePreferredAssignment(
        for task: DataModel.Task,
        in spreads: [DataModel.Spread]
    )
}

@MainActor
protocol NoteAssignmentReconciler {
    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread]
    )
}

@MainActor
struct StandardTaskAssignmentReconciler: TaskAssignmentReconciler {
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

    private func migrateActiveAssignmentsToHistory(_ task: DataModel.Task) {
        for index in task.assignments.indices where task.assignments[index].status != .migrated {
            task.assignments[index].status = .migrated
        }
    }
}

@MainActor
struct StandardNoteAssignmentReconciler: NoteAssignmentReconciler {
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread]
    ) {
        let destination = spreadService.findBestSpread(for: note, in: spreads)

        if let destination {
            if let destinationIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                for index in note.assignments.indices where index != destinationIndex && note.assignments[index].status != .migrated {
                    note.assignments[index].status = .migrated
                }
                note.assignments[destinationIndex].status = .active
            } else {
                migrateActiveAssignmentsToHistory(note)
                note.assignments.append(
                    NoteAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: .active
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(note)
        }
    }

    private func migrateActiveAssignmentsToHistory(_ note: DataModel.Note) {
        for index in note.assignments.indices where note.assignments[index].status != .migrated {
            note.assignments[index].status = .migrated
        }
    }
}
