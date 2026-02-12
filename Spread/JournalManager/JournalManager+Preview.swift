import Foundation

extension JournalManager {
    /// A preview-compatible instance for SwiftUI previews.
    ///
    /// Includes sample inbox entries (unassigned tasks and notes).
    /// Uses an in-memory, synchronous setup to work within preview constraints.
    /// Not for production use.
    @MainActor
    static var previewInstance: JournalManager {
        let calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }()

        let today = Date()
        let policy = StandardCreationPolicy(today: today, firstWeekday: .sunday)

        // Create sample inbox entries (no assignments = appears in inbox)
        let sampleTasks = [
            DataModel.Task(title: "Buy groceries", date: today),
            DataModel.Task(title: "Call dentist", date: today)
        ]
        let sampleNotes = [
            DataModel.Note(title: "Meeting notes", date: today)
        ]

        return JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(tasks: sampleTasks),
            spreadRepository: InMemorySpreadRepository(),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(notes: sampleNotes),
            bujoMode: .conventional,
            creationPolicy: policy
        )
    }

    /// A preview-compatible instance with no inbox entries.
    ///
    /// Uses an in-memory, synchronous setup to work within preview constraints.
    /// Not for production use.
    @MainActor
    static var previewInstanceEmpty: JournalManager {
        let calendar = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }()

        let today = Date()
        let policy = StandardCreationPolicy(today: today, firstWeekday: .sunday)

        return JournalManager(
            calendar: calendar,
            today: today,
            taskRepository: InMemoryTaskRepository(),
            spreadRepository: InMemorySpreadRepository(),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: policy
        )
    }
}
