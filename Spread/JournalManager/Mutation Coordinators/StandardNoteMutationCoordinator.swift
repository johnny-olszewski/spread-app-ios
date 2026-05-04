//
//  StandardNoteMutationCoordinator.swift
//  Spread
//
//  Created by Johnny O on 4/30/26.
//

import Foundation

/// Standard implementation of `NoteMutationCoordinator`.
///
/// Uses `NoteAssignmentReconciler` for spread assignment logic and `TraditionalSpreadService`
/// for traditional-mode migration. All persistence goes through `noteRepository`.
@MainActor
struct StandardNoteMutationCoordinator: NoteMutationCoordinator {
    /// The repository used to persist and retrieve notes.
    let noteRepository: any NoteRepository
    /// Reconciler for updating note spread assignments after creation or date changes.
    let noteAssignmentReconciler: any NoteAssignmentReconciler
    /// Adapter for routing log messages through `OSLog`.
    let logger: LoggerAdapter
    /// Calendar used for date normalization and service initialization.
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func createNote(
        title: String,
        content: String,
        date: Date,
        period: Period,
        preferredSpreadID: UUID? = nil,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult {
        let normalizedDate = period.normalizeDate(date, calendar: calendar)
        let note = DataModel.Note(
            title: title,
            content: content,
            date: normalizedDate,
            period: period,
            assignments: []
        )

        noteAssignmentReconciler.reconcilePreferredAssignment(
            for: note,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )
        try await noteRepository.save(note)
        return NoteListMutationResult(
            note: note,
            notes: await noteRepository.getNotes(),
            mutation: JournalMutationResult(
                kind: .noteChanged(id: note.id),
                scope: .structural
            )
        )
    }

    func updateNoteDateAndPeriod(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        preferredSpreadID: UUID? = nil,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult {
        let normalizedDate = newPeriod.normalizeDate(newDate, calendar: calendar)
        note.date = normalizedDate
        note.period = newPeriod
        noteAssignmentReconciler.reconcilePreferredAssignment(
            for: note,
            in: spreads,
            preferredSpreadID: preferredSpreadID
        )
        try await noteRepository.save(note)
        return NoteListMutationResult(
            note: note,
            notes: await noteRepository.getNotes(),
            mutation: JournalMutationResult(
                kind: .noteChanged(id: note.id),
                scope: .structural
            )
        )
    }

    func traditionalMigrateNote(
        _ note: DataModel.Note,
        newDate: Date,
        newPeriod: Period,
        calendar: Calendar,
        spreads: [DataModel.Spread]
    ) async throws -> NoteListMutationResult {
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
