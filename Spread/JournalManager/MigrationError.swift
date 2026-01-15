/// Errors that can occur during entry migration.
enum MigrationError: Error {
    /// Events cannot be migrated (they use computed visibility).
    case eventMigrationNotSupported

    /// Cancelled tasks cannot be migrated.
    case taskCancelled

    /// The entry has no assignment on the source spread.
    case noSourceAssignment

    /// The destination spread cannot accept direct assignments (e.g., multiday).
    case destinationNotAssignable
}
