import struct Foundation.Calendar
import struct Foundation.Date

extension JournalManager {
    /// A preview-compatible instance for SwiftUI previews.
    ///
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
