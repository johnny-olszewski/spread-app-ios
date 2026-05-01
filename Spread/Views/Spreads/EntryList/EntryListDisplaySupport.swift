import Foundation

enum EntryListDisplaySupport {
    static func displayedEntries(
        for spreadDataModel: SpreadDataModel,
        configuration: EntryListConfiguration,
        calendar: Calendar
    ) -> [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: spreadDataModel.tasks)
        entries.append(
            contentsOf: displayedNotes(
                for: spreadDataModel,
                configuration: configuration,
                calendar: calendar
            )
        )
        return entries
    }

    static func displayedNotes(
        for spreadDataModel: SpreadDataModel,
        configuration: EntryListConfiguration,
        calendar: Calendar
    ) -> [DataModel.Note] {
        guard configuration.showsMigrationHistory else {
            return spreadDataModel.notes
        }

        return spreadDataModel.notes.filter { note in
            !isMigrated(note, on: spreadDataModel.spread, calendar: calendar)
        }
    }

    static func migratedNotes(
        for spreadDataModel: SpreadDataModel,
        configuration: EntryListConfiguration,
        calendar: Calendar
    ) -> [DataModel.Note] {
        guard configuration.showsMigrationHistory else {
            return []
        }

        return spreadDataModel.notes.filter { note in
            isMigrated(note, on: spreadDataModel.spread, calendar: calendar)
        }
    }

    private static func isMigrated(
        _ note: DataModel.Note,
        on spread: DataModel.Spread,
        calendar: Calendar
    ) -> Bool {
        note.assignments.contains { assignment in
            assignment.status == .migrated &&
            assignment.matches(
                period: spread.period,
                date: spread.date,
                calendar: calendar
            )
        }
    }
}
