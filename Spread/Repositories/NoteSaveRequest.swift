import Foundation

/// Pairs a note with its pre-mutation change descriptor for a batched `saveAll` call.
struct NoteSaveRequest {
    /// The note to save, already mutated to its new state.
    let note: DataModel.Note
    /// The note's identity/assignments/tags as they existed before mutation.
    let change: EntityChange<NoteAssignment>

    /// Creates a save request. Defaults to a brand-new note with no prior assignments or tags.
    init(note: DataModel.Note, change: EntityChange<NoteAssignment> = EntityChange()) {
        self.note = note
        self.change = change
    }
}
