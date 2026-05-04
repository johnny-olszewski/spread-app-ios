import Foundation

/// Determines which tasks and notes currently live in the Inbox.
///
/// An entry is considered "in the Inbox" when it has no spread assignment, or when none
/// of its non-migrated assignments match any existing spread. Events are excluded because
/// their visibility is computed from date range overlap, not assignments.
protocol InboxResolver {
    /// Returns all tasks and notes that have no matching spread assignment.
    ///
    /// - Cancelled tasks are excluded from Inbox (they are no longer actionable).
    /// - Notes with only migrated assignments are included (they need a new home).
    ///
    /// - Parameters:
    ///   - tasks: All tasks in the journal.
    ///   - notes: All notes in the journal.
    ///   - spreads: All existing spreads used to evaluate assignment matches.
    /// - Returns: An array of unassigned tasks and notes, in the order tasks then notes.
    func inboxEntries(
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        spreads: [DataModel.Spread]
    ) -> [any Entry]
}

/// Standard implementation of `InboxResolver`.
///
/// An entry is considered to have a matching assignment when at least one of its
/// non-migrated assignments matches an existing spread's period and date.
struct StandardInboxResolver: InboxResolver {
    /// The calendar used for assignment date matching.
    let calendar: Calendar

    func inboxEntries(
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        spreads: [DataModel.Spread]
    ) -> [any Entry] {
        var entries: [any Entry] = []

        for task in tasks where task.status != .cancelled {
            if task.assignments.isEmpty || !hasMatchingAssignment(for: task, in: spreads) {
                entries.append(task)
            }
        }

        for note in notes {
            if note.assignments.isEmpty || !hasMatchingAssignment(for: note, in: spreads) {
                entries.append(note)
            }
        }

        return entries
    }

    private func hasMatchingAssignment(for task: DataModel.Task, in spreads: [DataModel.Spread]) -> Bool {
        spreads.contains { spread in
            task.assignments.contains { assignment in
                assignment.status != .migrated &&
                assignment.matches(spread: spread, calendar: calendar)
            }
        }
    }

    private func hasMatchingAssignment(for note: DataModel.Note, in spreads: [DataModel.Spread]) -> Bool {
        spreads.contains { spread in
            note.assignments.contains { assignment in
                assignment.status != .migrated &&
                assignment.matches(spread: spread, calendar: calendar)
            }
        }
    }
}
