import Foundation

struct TaskSpreadDeletionPlan: Sendable {
    let taskID: UUID
    let sourceAssignmentIndex: Int
    let replacementAssignmentIndex: Int?
    let replacementAssignment: TaskAssignment?
    let preservedStatus: DataModel.Task.Status
}

struct NoteSpreadDeletionPlan: Sendable {
    let noteID: UUID
    let sourceAssignmentIndex: Int
    let replacementAssignmentIndex: Int?
    let replacementAssignment: NoteAssignment?
    let preservedStatus: DataModel.Note.Status
}

struct SpreadDeletionPlan: Sendable {
    let spread: DataModel.Spread
    let parentSpread: DataModel.Spread?
    let taskPlans: [TaskSpreadDeletionPlan]
    let notePlans: [NoteSpreadDeletionPlan]
}

struct SpreadDeletionResult {
    let plan: SpreadDeletionPlan
    let spreads: [DataModel.Spread]
    let tasks: [DataModel.Task]
    let notes: [DataModel.Note]
}

@MainActor
protocol SpreadDeletionPlanner {
    func makePlan(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) -> SpreadDeletionPlan
}

@MainActor
protocol SpreadDeletionCoordinator {
    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> SpreadDeletionResult
}

@MainActor
struct StandardSpreadDeletionPlanner: SpreadDeletionPlanner {
    let calendar: Calendar

    func makePlan(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) -> SpreadDeletionPlan {
        let parentSpread = findParentSpread(for: spread, in: spreads)

        let taskPlans = tasks.compactMap { task in
            makeTaskPlan(for: task, deleting: spread, parentSpread: parentSpread)
        }

        let notePlans = notes.compactMap { note in
            makeNotePlan(for: note, deleting: spread, parentSpread: parentSpread)
        }

        return SpreadDeletionPlan(
            spread: spread,
            parentSpread: parentSpread,
            taskPlans: taskPlans,
            notePlans: notePlans
        )
    }

    private func findParentSpread(
        for spread: DataModel.Spread,
        in spreads: [DataModel.Spread]
    ) -> DataModel.Spread? {
        var currentPeriod: Period? = spread.period.parentPeriod

        while let period = currentPeriod {
            let normalizedDate = period.normalizeDate(spread.date, calendar: calendar)
            if let parentSpread = spreads.first(where: { existingSpread in
                existingSpread.period == period &&
                existingSpread.period.normalizeDate(existingSpread.date, calendar: calendar) == normalizedDate
            }) {
                return parentSpread
            }
            currentPeriod = period.parentPeriod
        }

        return nil
    }

    private func makeTaskPlan(
        for task: DataModel.Task,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?
    ) -> TaskSpreadDeletionPlan? {
        guard let sourceAssignmentIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }) else {
            return nil
        }

        let preservedStatus = task.assignments[sourceAssignmentIndex].status
        let replacementAssignmentIndex = parentSpread.flatMap { parent in
            task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: parent.period, date: parent.date, calendar: calendar)
            })
        }

        let replacementAssignment = parentSpread.flatMap { parent -> TaskAssignment? in
            guard replacementAssignmentIndex == nil else { return nil }
            return TaskAssignment(
                period: parent.period,
                date: parent.date,
                status: preservedStatus
            )
        }

        return TaskSpreadDeletionPlan(
            taskID: task.id,
            sourceAssignmentIndex: sourceAssignmentIndex,
            replacementAssignmentIndex: replacementAssignmentIndex,
            replacementAssignment: replacementAssignment,
            preservedStatus: preservedStatus
        )
    }

    private func makeNotePlan(
        for note: DataModel.Note,
        deleting spread: DataModel.Spread,
        parentSpread: DataModel.Spread?
    ) -> NoteSpreadDeletionPlan? {
        guard let sourceAssignmentIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }) else {
            return nil
        }

        let preservedStatus = note.assignments[sourceAssignmentIndex].status
        let replacementAssignmentIndex = parentSpread.flatMap { parent in
            note.assignments.firstIndex(where: { assignment in
                assignment.matches(period: parent.period, date: parent.date, calendar: calendar)
            })
        }

        let replacementAssignment = parentSpread.flatMap { parent -> NoteAssignment? in
            guard replacementAssignmentIndex == nil else { return nil }
            return NoteAssignment(
                period: parent.period,
                date: parent.date,
                status: preservedStatus
            )
        }

        return NoteSpreadDeletionPlan(
            noteID: note.id,
            sourceAssignmentIndex: sourceAssignmentIndex,
            replacementAssignmentIndex: replacementAssignmentIndex,
            replacementAssignment: replacementAssignment,
            preservedStatus: preservedStatus
        )
    }
}

@MainActor
struct StandardSpreadDeletionCoordinator: SpreadDeletionCoordinator {
    let planner: any SpreadDeletionPlanner
    let spreadRepository: any SpreadRepository
    let taskRepository: any TaskRepository
    let noteRepository: any NoteRepository
    let logger: LoggerAdapter

    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> SpreadDeletionResult {
        let plan = planner.makePlan(
            for: spread,
            spreads: spreads,
            tasks: tasks,
            notes: notes
        )

        for taskPlan in plan.taskPlans {
            guard let task = tasks.first(where: { $0.id == taskPlan.taskID }) else { continue }
            task.assignments[taskPlan.sourceAssignmentIndex].status = .migrated
            if let replacementAssignmentIndex = taskPlan.replacementAssignmentIndex {
                task.assignments[replacementAssignmentIndex].status = taskPlan.preservedStatus
            } else if let replacementAssignment = taskPlan.replacementAssignment {
                task.assignments.append(replacementAssignment)
            }
            try await taskRepository.save(task)
        }

        for notePlan in plan.notePlans {
            guard let note = notes.first(where: { $0.id == notePlan.noteID }) else { continue }
            note.assignments[notePlan.sourceAssignmentIndex].status = .migrated
            if let replacementAssignmentIndex = notePlan.replacementAssignmentIndex {
                note.assignments[replacementAssignmentIndex].status = notePlan.preservedStatus
            } else if let replacementAssignment = notePlan.replacementAssignment {
                note.assignments.append(replacementAssignment)
            }
            try await noteRepository.save(note)
        }

        try await spreadRepository.delete(spread)
        logger.info("Spread deleted: \(spread.period.rawValue) spread \(spread.id)")

        return SpreadDeletionResult(
            plan: plan,
            spreads: await spreadRepository.getSpreads(),
            tasks: await taskRepository.getTasks(),
            notes: await noteRepository.getNotes()
        )
    }
}
