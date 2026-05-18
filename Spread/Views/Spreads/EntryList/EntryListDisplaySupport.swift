import Foundation

enum EntryListDisplaySupport {
    static func displayedEntries(
        for spreadDataModel: SpreadDataModel,
        calendar: Calendar
    ) -> [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: spreadDataModel.tasks)
        entries.append(contentsOf: displayedNotes(for: spreadDataModel))
        return entries
    }

    static func displayedNotes(for spreadDataModel: SpreadDataModel) -> [DataModel.Note] {
        spreadDataModel.notes
    }
}
