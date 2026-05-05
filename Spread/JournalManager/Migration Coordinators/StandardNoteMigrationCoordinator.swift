import Foundation

/// Standard implementation of `NoteMigrationCoordinator`.
///
/// Persists all changes through `noteRepository` and logs each migration event.
@MainActor
struct StandardNoteMigrationCoordinator: NoteMigrationCoordinator {
    /// The repository used to persist and retrieve notes.
    let noteRepository: any NoteRepository
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter

    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> NoteListMutationResult {
        guard destination.period.canHaveTasksAssigned else {
            throw MigrationError.destinationNotAssignable
        }

        guard let sourceIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(spread: source, calendar: calendar)
        }) else {
            throw MigrationError.noSourceAssignment
        }

        note.assignments[sourceIndex].status = .migrated

        if let destinationIndex = note.assignments.firstIndex(where: { assignment in
            assignment.matches(spread: destination, calendar: calendar)
        }) {
            note.assignments[destinationIndex].status = .active
        } else {
            note.assignments.append(
                NoteAssignment(
                    period: destination.period,
                    date: destination.date,
                    spreadID: destination.period == .multiday ? destination.id : nil,
                    status: .active
                )
            )
        }

        try await noteRepository.save(note)
        logger.info("Migration performed: note \(note.id) from \(source.period.rawValue) to \(destination.period.rawValue)")
        return NoteListMutationResult(
            note: note,
            notes: await noteRepository.getNotes(),
            mutation: JournalMutationResult(
                kind: .noteChanged(id: note.id),
                scope: .structural
            )
        )
    }
}
