import Foundation
@testable import Spread

extension TestDataBuilders {

    /// A named set of tasks covering common status and assignment scenarios.
    struct TaskSet {
        /// An open task assigned to the day spread.
        let openOnDay: DataModel.Task
        /// A completed task assigned to the month spread.
        let completedOnMonth: DataModel.Task
        /// A migrated task with two assignments (month → day).
        let migratedFromMonthToDay: DataModel.Task
        /// A cancelled task.
        let cancelled: DataModel.Task
        /// An open task assigned to the year spread.
        let openOnYear: DataModel.Task
        /// An open task with no assignments yet.
        let unassigned: DataModel.Task

        /// All tasks in the set.
        var all: [DataModel.Task] {
            [openOnDay, completedOnMonth, migratedFromMonthToDay, cancelled, openOnYear, unassigned]
        }
    }

    /// Creates a comprehensive set of tasks with various statuses and assignments.
    ///
    /// Tasks are tied to the spreads that `spreads(calendar:today:)` would produce,
    /// so callers can pair them for integration scenarios.
    static func tasks(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> TaskSet {
        let yearDate = Period.year.normalizeDate(today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        return TaskSet(
            openOnDay: DataModel.Task(
                title: "Open day task",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .open,
                assignments: [
                    TaskAssignment(period: .day, date: dayDate, status: .open)
                ]
            ),
            completedOnMonth: DataModel.Task(
                title: "Completed month task",
                createdDate: today,
                date: monthDate,
                period: .month,
                status: .complete,
                assignments: [
                    TaskAssignment(period: .month, date: monthDate, status: .complete)
                ]
            ),
            migratedFromMonthToDay: DataModel.Task(
                title: "Migrated task",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .open,
                assignments: [
                    TaskAssignment(period: .month, date: monthDate, status: .migrated),
                    TaskAssignment(period: .day, date: dayDate, status: .open)
                ]
            ),
            cancelled: DataModel.Task(
                title: "Cancelled task",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .cancelled,
                assignments: [
                    TaskAssignment(period: .day, date: dayDate, status: .cancelled)
                ]
            ),
            openOnYear: DataModel.Task(
                title: "Open year task",
                createdDate: today,
                date: yearDate,
                period: .year,
                status: .open,
                assignments: [
                    TaskAssignment(period: .year, date: yearDate, status: .open)
                ]
            ),
            unassigned: DataModel.Task(
                title: "Unassigned task",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .open,
                assignments: []
            )
        )
    }
}
