import Foundation

extension Entry {

    /// The sort key used to order entries the conventional way spreads display them — by
    /// period-normalized date (so e.g. a month-level entry sorts at its month's start, not an
    /// arbitrary day within it), then entry type, then creation date, then `id` as a final
    /// deterministic tiebreaker.
    ///
    /// Used wherever entries spanning mixed periods need to interleave the way they'd naturally
    /// appear scrolling through Year/Month spread content — Year's month cards, Month's day
    /// sections, and the overdue card (which pulls tasks from across the whole journal,
    /// regardless of period).
    func conventionalSortKey(calendar: Calendar) -> (Date, Int, Date, UUID) {
        if let task = self as? DataModel.Task {
            let period = task.period ?? .day
            let date = task.date ?? task.createdDate
            return (
                period.normalizeDate(date, calendar: calendar),
                Self.conventionalEntryTypeSortOrder(task.entryType),
                task.createdDate,
                task.id
            )
        }
        if let note = self as? DataModel.Note {
            return (
                note.period.normalizeDate(note.date ?? note.createdDate, calendar: calendar),
                Self.conventionalEntryTypeSortOrder(note.entryType),
                note.createdDate,
                note.id
            )
        }
        return (.distantFuture, Self.conventionalEntryTypeSortOrder(entryType), createdDate, id)
    }

    private static func conventionalEntryTypeSortOrder(_ type: EntryType) -> Int {
        switch type {
        case .task: return 0
        case .note: return 1
        case .event: return 2
        }
    }
}
