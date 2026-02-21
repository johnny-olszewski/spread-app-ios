import Foundation
@testable import Spread

extension TestDataBuilders {

    /// A named set of notes covering common status and assignment scenarios.
    struct NoteSet {
        /// An active note assigned to the day spread.
        let activeOnDay: DataModel.Note
        /// An active note assigned to the month spread.
        let activeOnMonth: DataModel.Note
        /// A migrated note with two assignments (month → day).
        let migratedFromMonthToDay: DataModel.Note
        /// An active note with extended content.
        let withContent: DataModel.Note
        /// An active note with no assignments yet.
        let unassigned: DataModel.Note

        /// All notes in the set.
        var all: [DataModel.Note] {
            [activeOnDay, activeOnMonth, migratedFromMonthToDay, withContent, unassigned]
        }
    }

    /// Creates a comprehensive set of notes with various statuses and assignments.
    static func notes(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> NoteSet {
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        return NoteSet(
            activeOnDay: DataModel.Note(
                title: "Active day note",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .active,
                assignments: [
                    NoteAssignment(period: .day, date: dayDate, status: .active)
                ]
            ),
            activeOnMonth: DataModel.Note(
                title: "Active month note",
                createdDate: today,
                date: monthDate,
                period: .month,
                status: .active,
                assignments: [
                    NoteAssignment(period: .month, date: monthDate, status: .active)
                ]
            ),
            migratedFromMonthToDay: DataModel.Note(
                title: "Migrated note",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .active,
                assignments: [
                    NoteAssignment(period: .month, date: monthDate, status: .migrated),
                    NoteAssignment(period: .day, date: dayDate, status: .active)
                ]
            ),
            withContent: DataModel.Note(
                title: "Note with content",
                content: "Extended content for this note with multiple lines.\nLine two of the note.",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .active,
                assignments: [
                    NoteAssignment(period: .day, date: dayDate, status: .active)
                ]
            ),
            unassigned: DataModel.Note(
                title: "Unassigned note",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .active,
                assignments: []
            )
        )
    }
}
