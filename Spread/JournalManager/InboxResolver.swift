import Foundation

protocol InboxResolver {
    func inboxEntries(
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        spreads: [DataModel.Spread]
    ) -> [any Entry]
}

struct StandardInboxResolver: InboxResolver {
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
                assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
            }
        }
    }

    private func hasMatchingAssignment(for note: DataModel.Note, in spreads: [DataModel.Spread]) -> Bool {
        spreads.contains { spread in
            note.assignments.contains { assignment in
                assignment.status != .migrated &&
                assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
            }
        }
    }
}
