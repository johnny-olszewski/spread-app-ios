//
//  NoteMutationCoordinator.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Coordinates note creation and preferred-date mutation workflows.
///
/// Mirrors `TaskMutationCoordinator` for notes. Note assignments always use `.active` status.
@MainActor
protocol NoteMutationCoordinator {
    /// Creates a new note and assigns it to the best matching spread.
    ///
    /// The date is normalized to the period before the note is created. Assignment
    /// reconciliation runs immediately so the note lands on the correct spread
    /// (or Inbox if none matches).
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - content: The note body text.
    ///   - date: The user's chosen date.
    ///   - period: The user's chosen period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The new note and the refreshed full note list.
    /// - Throws: Repository errors if persistence fails.
    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        preferredSpreadID: UUID?,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult

    /// Updates a note's preferred date and period, then re-reconciles its spread assignment.
    ///
    /// - Parameters:
    ///   - note: The note to update.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used for assignment reconciliation.
    /// - Returns: The updated note and refreshed full note list.
    /// - Throws: Repository errors if persistence fails.
    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID?,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult

    /// Migrates a note to a new preferred date/period in traditional mode.
    ///
    /// Clears all existing assignments and creates a single new `.active` assignment
    /// on the nearest matching conventional spread (if one exists).
    ///
    /// - Parameters:
    ///   - note: The note to migrate.
    ///   - newDate: The new preferred date.
    ///   - newPeriod: The new preferred period.
    ///   - calendar: Calendar for date normalization and spread matching.
    ///   - spreads: The current spread list used to find the best conventional spread.
    /// - Returns: The updated note and refreshed full note list.
    /// - Throws: Repository errors if persistence fails.
    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult
}
