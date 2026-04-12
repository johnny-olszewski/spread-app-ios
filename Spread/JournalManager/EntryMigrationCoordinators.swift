import Foundation

@MainActor
protocol TaskMigrationCoordinator {
    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Task]

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult
}

@MainActor
protocol NoteMigrationCoordinator {
    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Note]
}

struct TaskBatchMigrationResult {
    let tasks: [DataModel.Task]
    let migratedAny: Bool
}

@MainActor
struct StandardTaskMigrationCoordinator: TaskMigrationCoordinator {
    let taskRepository: any TaskRepository
    let logger: LoggerAdapter

    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Task] {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        switch sourceKey.kind {
        case .inbox:
            break
        case .spread(_, let sourcePeriod, let sourceDate):
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: sourcePeriod, date: sourceDate, calendar: calendar)
            }) else {
                throw MigrationError.noSourceAssignment
            }
            task.assignments[sourceIndex].status = .migrated
        }

        if let destinationIndex = task.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            task.assignments[destinationIndex].status = .open
        } else {
            task.assignments.append(
                TaskAssignment(
                    period: destination.period,
                    date: destination.date,
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
        return await taskRepository.getTasks()
    }

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult {
        guard !tasks.isEmpty else {
            return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedAny: false)
        }

        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        var migratedAny = false

        for task in tasks {
            guard task.status != .cancelled else { continue }
            guard let sourceIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: source.period, date: source.date, calendar: calendar)
            }) else {
                continue
            }

            task.assignments[sourceIndex].status = .migrated

            if let destinationIndex = task.assignments.firstIndex(where: { assignment in
                assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
            }) {
                task.assignments[destinationIndex].status = .open
            } else {
                task.assignments.append(
                    TaskAssignment(
                        period: destination.period,
                        date: destination.date,
                        status: .open
                    )
                )
            }

            task.status = .open
            try await taskRepository.save(task)
            migratedAny = true
        }

        if migratedAny {
            logger.info(
                "Batch migration performed: \(tasks.count) task(s) from \(source.period.rawValue) to \(destination.period.rawValue)"
            )
        }

        return TaskBatchMigrationResult(tasks: await taskRepository.getTasks(), migratedAny: migratedAny)
    }
}

@MainActor
struct StandardNoteMigrationCoordinator: NoteMigrationCoordinator {
    let noteRepository: any NoteRepository
    let logger: LoggerAdapter

    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> [DataModel.Note] {
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        guard let sourceIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: source.period, date: source.date, calendar: calendar)
        }) else {
            throw MigrationError.noSourceAssignment
        }

        note.assignments[sourceIndex].status = .migrated

        if let destinationIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(period: destination.period, date: destination.date, calendar: calendar)
        }) {
            note.assignments[destinationIndex].status = .active
        } else {
            note.assignments.append(
                NoteAssignment(
                    period: destination.period,
                    date: destination.date,
                    status: .active
                )
            )
        }

        try await noteRepository.save(note)
        logger.info("Migration performed: note \(note.id) from \(source.period.rawValue) to \(destination.period.rawValue)")
        return await noteRepository.getNotes()
    }
}
