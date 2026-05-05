import Foundation

/// Coordinates explicit note migration workflows between spreads.
///
/// Notes support explicit-only migration (no batch). The source assignment is marked
/// `.migrated` and a new `.active` assignment is created on the destination.
@MainActor
protocol NoteMigrationCoordinator {
    /// Migrates a note from one spread to another.
    ///
    /// - Marks the source assignment `.migrated`.
    /// - Creates or updates the destination assignment to `.active`.
    /// - Persists the note and returns the refreshed full note list.
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - source: The spread to migrate from.
    ///   - destination: The spread to migrate to.
    ///   - calendar: Calendar used for assignment date matching.
    /// - Returns: The updated note and full updated note list from the repository.
    /// - Throws: `MigrationError` if the destination is not assignable or the source assignment
    ///   cannot be found.
    func migrateNote(
        _ note: DataModel.Note,
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> NoteListMutationResult
}
