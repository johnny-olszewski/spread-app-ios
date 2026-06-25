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
        let appClock = AppClock.fixed(
            now: today,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale ?? Locale(identifier: "en_US_POSIX")
        )

        // Create sample inbox entries (no assignments = appears in inbox)
        let sampleTasks = [
            DataModel.Task(title: "Buy groceries", date: today),
            DataModel.Task(title: "Call dentist", date: today)
        ]
        let sampleNotes = [
            DataModel.Note(title: "Meeting notes", date: today)
        ]

        let manager = JournalManager(
            appClock: appClock,
            taskRepository: TestChangeAwareTaskRepository(),
            noteRepository: TestChangeAwareNoteRepository(),
            spreadRepository: InMemorySpreadRepository(),
            eventRepository: InMemoryEventRepository(),
            creationPolicy: policy
        )
        // Populated synchronously via the in-memory upsert primitives rather than `load()`,
        // which is async — previews need a fully synchronous, already-populated instance.
        for task in sampleTasks {
            manager.upsertTask(task)
        }
        for note in sampleNotes {
            manager.upsertNote(note)
        }
        return manager
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
        let appClock = AppClock.fixed(
            now: today,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale ?? Locale(identifier: "en_US_POSIX")
        )

        return JournalManager(
            appClock: appClock,
            taskRepository: TestChangeAwareTaskRepository(),
            noteRepository: TestChangeAwareNoteRepository(),
            spreadRepository: InMemorySpreadRepository(),
            eventRepository: InMemoryEventRepository(),
            creationPolicy: policy
        )
    }
}
