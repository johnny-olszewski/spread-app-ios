//
//  NoteAssignmentReconciler.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Reconciles a note's spread assignment against the set of currently existing spreads.
///
/// Mirrors `TaskAssignmentReconciler` for notes. Notes always land on a spread with
/// `.active` status (they do not carry a completion state at the assignment level).
@MainActor
protocol NoteAssignmentReconciler {
    /// Updates the note's assignments so that the best matching spread is the active destination.
    ///
    /// Mutates `note.assignments` in-place. Does not persist; callers must save the note afterward.
    ///
    /// - Parameters:
    ///   - note: The note whose assignment should be reconciled.
    ///   - spreads: The full list of existing spreads to search.
    ///   - preferredSpreadID: Explicit multiday spread identity when the user
    ///     directly selected one.
    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID?
    )
}
