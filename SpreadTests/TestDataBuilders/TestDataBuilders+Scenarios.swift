import Foundation
@testable import Spread

extension TestDataBuilders {

    // MARK: - Migration Chain

    /// Data for testing a multi-hop migration chain: year → month → day.
    struct MigrationChainData {
        let yearSpread: DataModel.Spread
        let monthSpread: DataModel.Spread
        let daySpread: DataModel.Spread
        /// A task that has been migrated year → month → day, now open on day.
        let task: DataModel.Task
        /// A note that has been migrated month → day, now active on day.
        let note: DataModel.Note

        var allSpreads: [DataModel.Spread] { [yearSpread, monthSpread, daySpread] }
    }

    /// Creates a migration chain scenario with entries migrated through multiple spreads.
    ///
    /// The task has three assignments (year→migrated, month→migrated, day→open).
    /// The note has two assignments (month→migrated, day→active).
    static func migrationChainSetup(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> MigrationChainData {
        let yearDate = Period.year.normalizeDate(today, calendar: calendar)
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        let yearSpread = DataModel.Spread(period: .year, date: today, calendar: calendar)
        let monthSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let daySpread = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let task = DataModel.Task(
            title: "Chain-migrated task",
            createdDate: today,
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [
                TaskAssignment(period: .year, date: yearDate, status: .migrated),
                TaskAssignment(period: .month, date: monthDate, status: .migrated),
                TaskAssignment(period: .day, date: dayDate, status: .open)
            ]
        )

        let note = DataModel.Note(
            title: "Chain-migrated note",
            createdDate: today,
            date: dayDate,
            period: .day,
            status: .active,
            assignments: [
                NoteAssignment(period: .month, date: monthDate, status: .migrated),
                NoteAssignment(period: .day, date: dayDate, status: .active)
            ]
        )

        return MigrationChainData(
            yearSpread: yearSpread,
            monthSpread: monthSpread,
            daySpread: daySpread,
            task: task,
            note: note
        )
    }

    // MARK: - Batch Migration

    /// Data for testing batch migration of multiple entries from one spread to another.
    struct BatchMigrationData {
        let sourceSpread: DataModel.Spread
        let destinationSpread: DataModel.Spread
        /// Multiple open tasks assigned to the source spread, ready for batch migration.
        let tasks: [DataModel.Task]
        /// Multiple active notes assigned to the source spread, ready for batch migration.
        let notes: [DataModel.Note]

        var allSpreads: [DataModel.Spread] { [sourceSpread, destinationSpread] }
    }

    /// Creates a batch migration scenario with multiple entries on a source spread.
    ///
    /// Returns 3 tasks and 2 notes, all assigned to the month spread (source),
    /// with a day spread as the destination.
    static func batchMigrationSetup(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> BatchMigrationData {
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        let source = DataModel.Spread(period: .month, date: today, calendar: calendar)
        let destination = DataModel.Spread(period: .day, date: today, calendar: calendar)

        let batchTasks = (1...3).map { index in
            DataModel.Task(
                title: "Batch task \(index)",
                createdDate: today,
                date: monthDate,
                period: .month,
                status: .open,
                assignments: [
                    TaskAssignment(period: .month, date: monthDate, status: .open)
                ]
            )
        }

        let batchNotes = (1...2).map { index in
            DataModel.Note(
                title: "Batch note \(index)",
                createdDate: today,
                date: monthDate,
                period: .month,
                status: .active,
                assignments: [
                    NoteAssignment(period: .month, date: monthDate, status: .active)
                ]
            )
        }

        return BatchMigrationData(
            sourceSpread: source,
            destinationSpread: destination,
            tasks: batchTasks,
            notes: batchNotes
        )
    }

    // MARK: - Spread Deletion

    /// Data for testing spread deletion with attached entries.
    struct SpreadDeletionData {
        /// The spread to be deleted.
        let targetSpread: DataModel.Spread
        /// A sibling spread that should survive deletion.
        let siblingSpread: DataModel.Spread
        /// Tasks assigned to the target spread.
        let tasksOnTarget: [DataModel.Task]
        /// A task assigned to the sibling spread (should be unaffected).
        let taskOnSibling: DataModel.Task
        /// Notes assigned to the target spread.
        let notesOnTarget: [DataModel.Note]

        var allSpreads: [DataModel.Spread] { [targetSpread, siblingSpread] }
        var allTasks: [DataModel.Task] { tasksOnTarget + [taskOnSibling] }
    }

    /// Creates a spread deletion scenario with entries on both target and sibling spreads.
    ///
    /// The target (day) spread has 2 tasks and 1 note assigned to it.
    /// The sibling (month) spread has 1 task that should be unaffected by deletion.
    static func spreadDeletionSetup(
        calendar: Calendar = testCalendar,
        today: Date = testDate
    ) -> SpreadDeletionData {
        let monthDate = Period.month.normalizeDate(today, calendar: calendar)
        let dayDate = Period.day.normalizeDate(today, calendar: calendar)

        let targetSpread = DataModel.Spread(period: .day, date: today, calendar: calendar)
        let siblingSpread = DataModel.Spread(period: .month, date: today, calendar: calendar)

        let tasksOnTarget = (1...2).map { index in
            DataModel.Task(
                title: "Target task \(index)",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .open,
                assignments: [
                    TaskAssignment(period: .day, date: dayDate, status: .open)
                ]
            )
        }

        let taskOnSibling = DataModel.Task(
            title: "Sibling task",
            createdDate: today,
            date: monthDate,
            period: .month,
            status: .open,
            assignments: [
                TaskAssignment(period: .month, date: monthDate, status: .open)
            ]
        )

        let notesOnTarget = [
            DataModel.Note(
                title: "Target note",
                createdDate: today,
                date: dayDate,
                period: .day,
                status: .active,
                assignments: [
                    NoteAssignment(period: .day, date: dayDate, status: .active)
                ]
            )
        ]

        return SpreadDeletionData(
            targetSpread: targetSpread,
            siblingSpread: siblingSpread,
            tasksOnTarget: tasksOnTarget,
            taskOnSibling: taskOnSibling,
            notesOnTarget: notesOnTarget
        )
    }

    // MARK: - Boundary Scenarios

    /// Data for testing month and year boundary crossing.
    struct BoundaryData {
        /// Day spread for Dec 31.
        let lastDayOfYear: DataModel.Spread
        /// Day spread for Jan 1 of the next year.
        let firstDayOfNextYear: DataModel.Spread
        /// Month spread for December.
        let december: DataModel.Spread
        /// Month spread for January of the next year.
        let january: DataModel.Spread
        /// Year spread for the current year.
        let currentYear: DataModel.Spread
        /// Year spread for the next year.
        let nextYear: DataModel.Spread
        /// Task assigned to Dec 31 day spread.
        let taskOnLastDay: DataModel.Task
        /// Multiday spread spanning Dec 30 – Jan 2 (crosses year boundary).
        let crossYearMultiday: DataModel.Spread

        var allSpreads: [DataModel.Spread] {
            [lastDayOfYear, firstDayOfNextYear, december, january,
             currentYear, nextYear, crossYearMultiday]
        }
    }

    /// Creates spreads and entries at month/year boundaries for edge-case testing.
    static func boundarySetup(
        calendar: Calendar = testCalendar,
        year: Int = testYear
    ) -> BoundaryData {
        let dec31 = makeDate(year: year, month: 12, day: 31, calendar: calendar)
        let jan1 = makeDate(year: year + 1, month: 1, day: 1, calendar: calendar)
        let dec30 = makeDate(year: year, month: 12, day: 30, calendar: calendar)
        let jan2 = makeDate(year: year + 1, month: 1, day: 2, calendar: calendar)

        let dec31Date = Period.day.normalizeDate(dec31, calendar: calendar)

        return BoundaryData(
            lastDayOfYear: DataModel.Spread(period: .day, date: dec31, calendar: calendar),
            firstDayOfNextYear: DataModel.Spread(period: .day, date: jan1, calendar: calendar),
            december: DataModel.Spread(period: .month, date: dec31, calendar: calendar),
            january: DataModel.Spread(period: .month, date: jan1, calendar: calendar),
            currentYear: DataModel.Spread(period: .year, date: dec31, calendar: calendar),
            nextYear: DataModel.Spread(period: .year, date: jan1, calendar: calendar),
            taskOnLastDay: DataModel.Task(
                title: "Year-end task",
                createdDate: dec31,
                date: dec31Date,
                period: .day,
                status: .open,
                assignments: [
                    TaskAssignment(period: .day, date: dec31Date, status: .open)
                ]
            ),
            crossYearMultiday: DataModel.Spread(
                startDate: dec30,
                endDate: jan2,
                calendar: calendar
            )
        )
    }
}
