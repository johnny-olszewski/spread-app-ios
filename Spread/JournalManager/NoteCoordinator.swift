import Foundation
import OSLog

/// Workflow coordinator for note creation, metadata updates, and migration.
///
/// Concrete, no protocol declaration, no "Standard" naming — per
/// `Documentation/Specs/JournalManager.md`'s "Decision: Drop protocol-per-logic-seam;
/// protocols are a repository-only boundary." Depends only on `NoteRepository` (the
/// genuine substitution boundary) and `JournalRuleEngine` (SPRD-248, for assignment
/// reconciliation and migration mechanics) — not on `JournalManager` itself.
///
/// See `TaskCoordinator`'s doc comment for the design rationale shared by both types
/// (no protocol, no back-reference to `JournalManager`, callers pass `spreads` in and
/// upsert the mutated entity into their own observed state afterward).
///
/// Used by `JournalManager`'s note CRUD/migration methods (`addNote`,
/// `updateNoteTitle`/`updateNoteMetadata`/`updateNoteDateAndPeriod`, `deleteNote`,
/// `migrateNote`), which delegate to this type and then patch their own incremental
/// index via `upsertNote`/`removeNote`.
@MainActor
struct NoteCoordinator {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "NoteCoordinator")

    /// Repository for note persistence and sync-outbox diffing.
    let noteRepository: any NoteRepository

    /// Rule engine for assignment reconciliation and migration mechanics.
    let ruleEngine: JournalRuleEngine

    // MARK: - Creation

    /// Creates a new note, reconciling its preferred assignment against `spreads`.
    @discardableResult
    func addNote(
        title: String,
        content: String = "",
        date: Date,
        period: Period,
        preferredSpreadID: UUID? = nil,
        spreads: [DataModel.Spread]
    ) async throws -> DataModel.Note {
        let note = DataModel.Note(
            title: title,
            content: content,
            date: period.normalizeDate(date, calendar: ruleEngine.calendar),
            period: period,
            currentAssignments: []
        )
        ruleEngine.reconcilePreferredAssignment(for: note, in: spreads, preferredSpreadID: preferredSpreadID)
        try await noteRepository.save(note, change: EntityChange(isNew: true))

        if note.currentAssignments.isEmpty {
            Self.logger.debug("Note created: \(note.id, privacy: .public) '\(note.title, privacy: .public)' → Inbox (no matching spread)")
        } else {
            Self.logger.debug("Note created: \(note.id, privacy: .public) '\(note.title, privacy: .public)' → \(note.period.rawValue, privacy: .public) spread")
        }

        return note
    }

    // MARK: - Updates

    /// Updates a note's title and content.
    func updateTitle(_ note: DataModel.Note, newTitle: String, newContent: String) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: note.currentAssignments + note.migrationHistory,
            previousTagIDs: note.tags.map(\.id)
        )
        note.title = newTitle
        note.content = newContent
        try await noteRepository.save(note, change: change)
    }

    /// Updates independently mergeable note metadata (list/tags).
    func updateMetadata(_ note: DataModel.Note, list: DataModel.List?, tags: [DataModel.Tag]) async throws {
        let previousTagIDs = note.tags.map(\.id)
        let timestamp = Date.now

        if note.list?.id != list?.id {
            note.list = list
            note.listUpdatedAt = timestamp
        }
        if Set(previousTagIDs) != Set(tags.map(\.id)) {
            note.tags = tags
        }

        try await noteRepository.save(
            note,
            change: EntityChange(
                isNew: false,
                previousAssignments: note.currentAssignments + note.migrationHistory,
                previousTagIDs: previousTagIDs
            )
        )
    }

    /// Updates a note's preferred date and period, reconciling its spread assignment
    /// against `spreads`.
    func updateDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil,
        spreads: [DataModel.Spread]
    ) async throws {
        let change = EntityChange(
            isNew: false,
            previousAssignments: note.currentAssignments + note.migrationHistory,
            previousTagIDs: note.tags.map(\.id)
        )
        note.date = newPeriod.normalizeDate(newDate, calendar: ruleEngine.calendar)
        note.period = newPeriod
        ruleEngine.reconcilePreferredAssignment(for: note, in: spreads, preferredSpreadID: preferredSpreadID)
        try await noteRepository.save(note, change: change)
    }

    // MARK: - Deletion

    /// Deletes a note from the repository.
    func delete(_ note: DataModel.Note) async throws {
        try await noteRepository.delete(note)
    }

    // MARK: - Migration

    /// Migrates a note from one spread to another. Notes can only be migrated via explicit
    /// user action, not batch migration.
    func migrateNote(_ note: DataModel.Note, from source: DataModel.Spread, to destination: DataModel.Spread) async throws {
        guard destination.period.canHaveTasksAssigned else { throw MigrationError.destinationNotAssignable }
        guard note.currentAssignments.contains(where: { $0.matches(spread: source, calendar: ruleEngine.calendar) }) else {
            throw MigrationError.noSourceAssignment
        }
        let previousAssignments = note.currentAssignments + note.migrationHistory

        ruleEngine.migrateAssignment(
            for: note,
            matchingSource: { $0.matches(spread: source, calendar: ruleEngine.calendar) },
            to: destination,
            status: .active
        )

        try await noteRepository.save(
            note,
            change: EntityChange(isNew: false, previousAssignments: previousAssignments, previousTagIDs: note.tags.map(\.id))
        )
    }
}
