import Foundation

struct TaskMutationResult {
    let task: DataModel.Task
    let tasks: [DataModel.Task]
}

struct NoteMutationResult {
    let note: DataModel.Note
    let notes: [DataModel.Note]
}

@MainActor
protocol TaskMutationCoordinator {
    func createTask(
        title: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskMutationResult

    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task]

    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task]
}

@MainActor
protocol NoteMutationCoordinator {
    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteMutationResult

    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note]

    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note]
}

@MainActor
struct StandardTaskMutationCoordinator: TaskMutationCoordinator {
    let taskRepository: any TaskRepository
    let taskAssignmentReconciler: any TaskAssignmentReconciler
    let logger: LoggerAdapter
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createTask(
        title: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> TaskMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let task = DataModel.Task(
            title: title,
            createdDate: .now,
            date: normalizedDate,
            period: period,
            status: .open,
            assignments: []
        )

        taskAssignmentReconciler.reconcilePreferredAssignment(for: task, in: spreads)
        try await taskRepository.save(task)
        return TaskMutationResult(task: task, tasks: await taskRepository.getTasks())
    }

    func updateTaskDateAndPeriod(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
        taskAssignmentReconciler.reconcilePreferredAssignment(for: task, in: spreads)
        try await taskRepository.save(task)
        return await taskRepository.getTasks()
    }

    func traditionalMigrateTask(
        _ task: DataModel.Task,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Task] {
        guard task.status != .cancelled else {
            throw MigrationError.taskCancelled
        }

        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        task.date = normalizedDate
        task.period = newPeriod
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
        return await taskRepository.getTasks()
    }
}

@MainActor
struct StandardNoteMutationCoordinator: NoteMutationCoordinator {
    let noteRepository: any NoteRepository
    let noteAssignmentReconciler: any NoteAssignmentReconciler
    let logger: LoggerAdapter
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let note = DataModel.Note(
            title: title,
            content: content,
            date: normalizedDate,
            period: period,
            assignments: []
        )

        noteAssignmentReconciler.reconcilePreferredAssignment(for: note, in: spreads)
        try await noteRepository.save(note)
        return NoteMutationResult(note: note, notes: await noteRepository.getNotes())
    }

    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.date = normalizedDate
        note.period = newPeriod
        noteAssignmentReconciler.reconcilePreferredAssignment(for: note, in: spreads)
        try await noteRepository.save(note)
        return await noteRepository.getNotes()
    }

    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> [DataModel.Note] {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.date = normalizedDate
        note.period = newPeriod
        note.assignments.removeAll()

        if let bestSpread = traditionalSpreadService.findConventionalSpread(
            forPreferredDate: normalizedDate,
            preferredPeriod: newPeriod,
            in: spreads
        ) {
            note.assignments.append(
                NoteAssignment(
                    period: bestSpread.period,
                    date: bestSpread.date,
                    status: .active
                )
            )
        }

        try await noteRepository.save(note)
        logger.info("Traditional migration: note \(note.id) → \(newPeriod.rawValue) \(normalizedDate)")
        return await noteRepository.getNotes()
    }
}

struct LoggerAdapter {
    let info: (String) -> Void
}
