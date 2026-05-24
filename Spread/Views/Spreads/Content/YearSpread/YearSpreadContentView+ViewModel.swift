import Foundation

extension YearSpreadContentView {

    /// Owns the year-level entry list and helper methods for `YearSpreadContentView`.
    @Observable @MainActor
    final class ViewModel {
        private(set) var yearEntries: [any Entry] = []

        init() {}

        // MARK: - Lifecycle

        func configure(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            journalManager: JournalManager
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            yearEntries = Self.buildYearEntries(from: spreadDataModel, calendar: cal)
        }

        func refreshYearEntries(
            spread: DataModel.Spread,
            spreadDataModel: SpreadDataModel,
            journalManager: JournalManager
        ) {
            let cal = journalManager.firstWeekday.configuredCalendar(from: journalManager.calendar)
            yearEntries = Self.buildYearEntries(from: spreadDataModel, calendar: cal)
        }

        // MARK: - Static helpers

        static func entriesForMonth(_ monthDate: Date, from spreadDataModel: SpreadDataModel, calendar: Calendar) -> [any Entry] {
            let normalizedMonth = Period.month.normalizeDate(monthDate, calendar: calendar)
            var allEntries: [any Entry] = []
            allEntries.append(contentsOf: spreadDataModel.tasks)
            allEntries.append(contentsOf: spreadDataModel.notes)
            return allEntries
                .filter { entry in
                    guard let candidateMonth = monthCardMonthDate(for: entry, calendar: calendar) else { return false }
                    return candidateMonth == normalizedMonth
                }
                .sorted { lhs, rhs in
                    sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
                }
        }

        // MARK: - Private

        private static func buildYearEntries(from spreadDataModel: SpreadDataModel, calendar: Calendar) -> [any Entry] {
            var entries: [any Entry] = []
            entries.append(contentsOf: spreadDataModel.tasks)
            entries.append(contentsOf: spreadDataModel.notes)
            return entries
                .filter(isTopYearSectionEntry)
                .sorted { lhs, rhs in
                    sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
                }
        }

        private static func isTopYearSectionEntry(_ entry: any Entry) -> Bool {
            if let task = entry as? DataModel.Task { return task.period == .year }
            if let note = entry as? DataModel.Note { return note.period == .year }
            return false
        }

        private static func monthCardMonthDate(for entry: any Entry, calendar: Calendar) -> Date? {
            if let task = entry as? DataModel.Task,
               task.period == .month || task.period == .day {
                return Period.month.normalizeDate(task.date, calendar: calendar)
            }
            if let note = entry as? DataModel.Note,
               note.period == .month || note.period == .day {
                return Period.month.normalizeDate(note.date, calendar: calendar)
            }
            return nil
        }

        private static func sortKey(for entry: any Entry, calendar: Calendar) -> (Date, Int, Date, UUID) {
            if let task = entry as? DataModel.Task {
                return (
                    task.period.normalizeDate(task.date, calendar: calendar),
                    entryTypeSortOrder(task.entryType),
                    task.createdDate,
                    task.id
                )
            }
            if let note = entry as? DataModel.Note {
                return (
                    note.period.normalizeDate(note.date, calendar: calendar),
                    entryTypeSortOrder(note.entryType),
                    note.createdDate,
                    note.id
                )
            }
            return (.distantFuture, entryTypeSortOrder(entry.entryType), entry.createdDate, entry.id)
        }

        private static func entryTypeSortOrder(_ type: EntryType) -> Int {
            switch type {
            case .task: return 0
            case .note: return 1
            case .event: return 2
            }
        }
    }
}
