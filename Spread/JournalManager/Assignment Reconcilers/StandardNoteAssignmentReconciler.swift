//
//  StandardNoteAssignmentReconciler.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Standard implementation of `NoteAssignmentReconciler` using `ConventionalSpreadService`.
///
/// Mirrors `StandardTaskAssignmentReconciler` for notes. Destination assignments always
/// receive `.active` status regardless of the note's current state.
@MainActor
struct StandardNoteAssignmentReconciler: NoteAssignmentReconciler {
    /// The calendar used for date normalization and spread matching.
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func reconcilePreferredAssignment(
        for note: DataModel.Note,
        in spreads: [DataModel.Spread],
        preferredSpreadID: UUID? = nil
    ) {
        let destination = spreadService.findBestSpread(
            for: note,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )

        if let destination {
            if let destinationIndex = note.assignments.firstIndex(where: { assignment in
                assignment.matches(spread: destination, calendar: calendar)
            }) {
                for index in note.assignments.indices where index != destinationIndex && note.assignments[index].status != .migrated {
                    note.assignments[index].status = .migrated
                }
                note.assignments[destinationIndex].status = .active
            } else {
                migrateActiveAssignmentsToHistory(note)
                note.assignments.append(
                    NoteAssignment(
                        period: destination.period,
                        date: destination.date,
                        spreadID: destination.period == .multiday ? destination.id : nil,
                        status: .active
                    )
                )
            }
        } else {
            migrateActiveAssignmentsToHistory(note)
        }
    }

    /// Marks all non-migrated assignments on the note as `.migrated`.
    ///
    /// Used to archive the note's history before appending a new active assignment.
    private func migrateActiveAssignmentsToHistory(_ note: DataModel.Note) {
        for index in note.assignments.indices where note.assignments[index].status != .migrated {
            note.assignments[index].status = .migrated
        }
    }
}
