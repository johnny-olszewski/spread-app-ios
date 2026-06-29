import Foundation

extension SpreadDataModel {
    /// Returns the full current entry set (tasks + notes) for this spread data model.
    func displayedEntries(calendar: Calendar) -> [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: tasks)
        entries.append(contentsOf: displayedNotes)
        return entries
    }

    /// All notes for this spread data model, regardless of migration status.
    var displayedNotes: [DataModel.Note] {
        notes
    }
}
