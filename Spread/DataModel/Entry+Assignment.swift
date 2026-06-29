import Foundation

extension Entry {
    /// The list this entry belongs to, or `nil` if it is unassigned or not list-eligible.
    var assignedList: DataModel.List? {
        if let task = self as? DataModel.Task { return task.list }
        if let note = self as? DataModel.Note { return note.list }
        return nil
    }

    /// The tags applied to this entry, or empty if untagged or not tag-eligible.
    var assignedTags: [DataModel.Tag] {
        if let task = self as? DataModel.Task { return task.tags }
        if let note = self as? DataModel.Note { return note.tags }
        return []
    }
}
