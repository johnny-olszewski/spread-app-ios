import Foundation

/// Summarizes entries automatically migrated into a newly created explicit spread.
struct SpreadAutoMigrationSummary: Equatable {
    let taskCount: Int
    let noteCount: Int

    var totalCount: Int {
        taskCount + noteCount
    }

    var message: String {
        let taskPart = taskCount > 0 ? "\(taskCount) task\(taskCount == 1 ? "" : "s")" : nil
        let notePart = noteCount > 0 ? "\(noteCount) note\(noteCount == 1 ? "" : "s")" : nil
        let parts = [taskPart, notePart].compactMap { $0 }
        let subject = parts.isEmpty ? "Entries" : parts.joined(separator: " and ")
        return "\(subject) moved automatically"
    }
}

/// Result of creating a new explicit spread, including any auto-migration summary produced
/// by the conventional year/month/day reconciliation pass.
struct SpreadCreationOperationResult {
    let spread: DataModel.Spread
    let autoMigrationSummary: SpreadAutoMigrationSummary?
}
