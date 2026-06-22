import Foundation

/// Standard implementation of `TaskMigrationCoordinator`.
///
/// Persists all changes through `taskRepository` and logs each migration event.
@MainActor
struct StandardTaskMigrationCoordinator: TaskMigrationCoordinator {
    /// The repository used to persist and retrieve tasks.
    let taskRepository: any TaskRepository
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter

    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskListMutationResult {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        switch sourceKey.kind {
        case .inbox:
            break
        case .spread(let sourceSpreadID, let sourcePeriod, let sourceDate):
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(
                    period: sourcePeriod,
                    date: sourceDate,
                    spreadID: sourceSpreadID,
                    calendar: calendar
                )
            }) else {
                throw MigrationError.noSourceAssignment
            }
            task.assignments[sourceIndex].status = .migrated
        }

        if let destinationIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(spread: destination, calendar: calendar)
        }) {
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
        try await taskRepository.save(task)

        let sourceDescription: String = switch sourceKey.kind {
        case .inbox:
            "inbox"
        case .spread(_, let period, _):
            period.rawValue
        }
        logger.info("Migration performed: task \(task.id) from \(sourceDescription) to \(destination.period.rawValue)")
        return TaskListMutationResult(
            task: task,
            tasks: await taskRepository.getTasks(),
            mutation: JournalMutationResult(
                kind: .taskChanged(id: task.id),
                scope: .structural
            )
        )
    }

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult {
        guard !tasks.isEmpty else {
            return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedTasks: [], migratedAny: false)
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        var migratedAny = false
        var migratedTasks: [DataModel.Task] = []

        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: source, calendar: calendar)
            }) else {
                continue
            }

            task.assignments[sourceIndex].status = .migrated

            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: destination, calendar: calendar)
            }) {
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
            try await taskRepository.save(task)
            migratedAny = true
            migratedTasks.append(task)
        }

        if migratedAny {
            logger.info(
                "Batch migration performed: \(tasks.count) task(s) from \(source.period.rawValue) to \(destination.period.rawValue)"
            )
        }

        return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedTasks: migratedTasks, migratedAny: migratedAny)
    }
}
