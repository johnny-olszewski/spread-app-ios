import struct Foundation.Date
import struct Foundation.UUID

/// Sample data for previews and testing.
///
/// Provides realistic test data for SwiftUI previews and unit tests.
/// All methods return new instances on each call for isolation.
enum TestData {

    // MARK: - Tasks

    /// Creates sample tasks for previews.
    ///
    /// Returns a variety of tasks with different titles representing
    /// typical bullet journal entries.
    static func sampleTasks() -> [DataModel.Task] {
        let now = Date.now
        return [
            DataModel.Task(
                title: "Review project timeline",
                createdDate: now.addingTimeInterval(-86400 * 3)
            ),
            DataModel.Task(
                title: "Send weekly status update",
                createdDate: now.addingTimeInterval(-86400 * 2)
            ),
            DataModel.Task(
                title: "Schedule team meeting",
                createdDate: now.addingTimeInterval(-86400)
            ),
            DataModel.Task(
                title: "Prepare presentation slides",
                createdDate: now.addingTimeInterval(-3600)
            ),
            DataModel.Task(
                title: "Follow up with client",
                createdDate: now
            )
        ]
    }

    // MARK: - Spreads

    /// Creates sample spreads for previews.
    ///
    /// Returns spreads representing different time periods.
    static func sampleSpreads() -> [DataModel.Spread] {
        let now = Date.now
        return [
            DataModel.Spread(createdDate: now.addingTimeInterval(-86400 * 30)),
            DataModel.Spread(createdDate: now.addingTimeInterval(-86400 * 7)),
            DataModel.Spread(createdDate: now.addingTimeInterval(-86400)),
            DataModel.Spread(createdDate: now)
        ]
    }

    // MARK: - Events

    /// Creates sample events for previews.
    ///
    /// Returns events representing typical calendar entries.
    static func sampleEvents() -> [DataModel.Event] {
        let now = Date.now
        return [
            DataModel.Event(
                title: "Team standup",
                createdDate: now.addingTimeInterval(-86400)
            ),
            DataModel.Event(
                title: "Project deadline",
                createdDate: now
            ),
            DataModel.Event(
                title: "Quarterly review",
                createdDate: now.addingTimeInterval(86400 * 7)
            )
        ]
    }

    // MARK: - Notes

    /// Creates sample notes for previews.
    ///
    /// Returns notes representing typical journal entries.
    static func sampleNotes() -> [DataModel.Note] {
        let now = Date.now
        return [
            DataModel.Note(
                title: "Meeting notes from kickoff",
                createdDate: now.addingTimeInterval(-86400 * 2)
            ),
            DataModel.Note(
                title: "Ideas for new feature",
                createdDate: now.addingTimeInterval(-86400)
            ),
            DataModel.Note(
                title: "Book recommendations",
                createdDate: now
            )
        ]
    }

    // MARK: - Collections

    /// Creates sample collections for previews.
    ///
    /// Returns collections representing typical bullet journal collections.
    static func sampleCollections() -> [DataModel.Collection] {
        let now = Date.now
        return [
            DataModel.Collection(
                title: "Books to Read",
                createdDate: now.addingTimeInterval(-86400 * 14)
            ),
            DataModel.Collection(
                title: "Project Ideas",
                createdDate: now.addingTimeInterval(-86400 * 7)
            ),
            DataModel.Collection(
                title: "Goals for 2026",
                createdDate: now
            )
        ]
    }
}
