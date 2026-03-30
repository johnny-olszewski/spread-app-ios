#if DEBUG
import Foundation

extension MockDataSet {

    func generateScenarioAssignmentExistingSpread(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar),
                spread(.day, today, calendar: calendar)
            ],
            tasks: [],
            events: [],
            notes: []
        )
    }

    func generateScenarioAssignmentInboxFallback(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        GeneratedData(
            spreads: [],
            tasks: [],
            events: [],
            notes: []
        )
    }

    func generateScenarioInboxResolution(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let targetDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Inbox resolution task",
                    date: targetDay,
                    period: .day,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioMigrationMonthBound(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let targetDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar),
                spread(.day, targetDay, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Month-bound migration task",
                    date: targetDay,
                    period: .month,
                    assignmentPeriod: .year,
                    assignmentDate: yearStart,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioMigrationDayUpgrade(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let targetDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Day upgrade migration task",
                    date: targetDay,
                    period: .day,
                    assignmentPeriod: .year,
                    assignmentDate: yearStart,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioMigrationDaySuperseded(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let targetDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar),
                spread(.day, targetDay, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Day upgrade migration task",
                    date: targetDay,
                    period: .day,
                    assignmentPeriod: .year,
                    assignmentDate: yearStart,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioReassignment(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let yearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let monthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let futureDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, yearStart, calendar: calendar),
                spread(.month, monthStart, calendar: calendar),
                spread(.day, today, calendar: calendar),
                spread(.day, futureDay, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Reassign me",
                    date: today,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: today,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioOverdueReview(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let currentYearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let currentMonthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentYearStart) ?? currentYearStart
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let pastDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        return GeneratedData(
            spreads: [
                spread(.year, previousYearStart, calendar: calendar),
                spread(.year, currentYearStart, calendar: calendar),
                spread(.month, previousMonthStart, calendar: calendar),
                spread(.month, currentMonthStart, calendar: calendar),
                spread(.day, pastDay, calendar: calendar),
                spread(.day, today, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Overdue year task",
                    date: previousYearStart,
                    period: .year,
                    assignmentPeriod: .year,
                    assignmentDate: previousYearStart,
                    calendar: calendar
                ),
                task(
                    title: "Overdue month task",
                    date: previousMonthStart,
                    period: .month,
                    assignmentPeriod: .month,
                    assignmentDate: previousMonthStart,
                    calendar: calendar
                ),
                task(
                    title: "Overdue day task",
                    date: pastDay,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: pastDay,
                    calendar: calendar
                ),
                task(
                    title: "Current month task",
                    date: currentMonthStart,
                    period: .month,
                    assignmentPeriod: .month,
                    assignmentDate: currentMonthStart,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioOverdueInbox(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let currentYearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let currentMonthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let pastDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        return GeneratedData(
            spreads: [
                spread(.year, currentYearStart, calendar: calendar),
                spread(.month, currentMonthStart, calendar: calendar),
                spread(.day, today, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Inbox overdue month task",
                    date: previousMonthStart,
                    period: .month,
                    calendar: calendar
                ),
                task(
                    title: "Inbox overdue day task",
                    date: pastDay,
                    period: .day,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioTraditionalOverdue(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let currentYearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let currentMonthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let pastDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        let futureDay = futureScenarioDay(from: today, calendar: calendar)

        return GeneratedData(
            spreads: [
                spread(.year, currentYearStart, calendar: calendar),
                spread(.month, currentMonthStart, calendar: calendar),
                spread(.day, futureDay, calendar: calendar),
                spread(.day, pastDay, calendar: calendar),
                spread(.day, today, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Traditional overdue task",
                    date: pastDay,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: pastDay,
                    calendar: calendar
                ),
                task(
                    title: "Traditional migration candidate",
                    date: futureDay,
                    period: .day,
                    assignmentPeriod: .year,
                    assignmentDate: currentYearStart,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    func generateScenarioNoteExclusions(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let currentYearStart = today.firstDayOfYear(calendar: calendar) ?? today
        let currentMonthStart = today.firstDayOfMonth(calendar: calendar) ?? today
        let futureDay = futureScenarioDay(from: today, calendar: calendar)
        let pastDay = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        return GeneratedData(
            spreads: [
                spread(.year, currentYearStart, calendar: calendar),
                spread(.month, currentMonthStart, calendar: calendar),
                spread(.day, futureDay, calendar: calendar),
                spread(.day, pastDay, calendar: calendar),
                spread(.day, today, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Scenario migration task",
                    date: futureDay,
                    period: .day,
                    assignmentPeriod: .year,
                    assignmentDate: currentYearStart,
                    calendar: calendar
                ),
                task(
                    title: "Scenario overdue task",
                    date: pastDay,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: pastDay,
                    calendar: calendar
                )
            ],
            events: [],
            notes: [
                note(
                    title: "Scenario migration note",
                    date: futureDay,
                    period: .day,
                    assignmentPeriod: .year,
                    assignmentDate: currentYearStart,
                    calendar: calendar
                ),
                note(
                    title: "Scenario overdue note",
                    date: pastDay,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: pastDay,
                    calendar: calendar
                )
            ]
        )
    }

    func generateScenarioMultidayLayout(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let dayTwo = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let dayThree = calendar.date(byAdding: .day, value: 2, to: today) ?? today

        return GeneratedData(
            spreads: [
                DataModel.Spread(startDate: today, endDate: dayThree, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Middle day task",
                    date: dayTwo,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: dayTwo,
                    calendar: calendar
                )
            ],
            events: [],
            notes: [
                note(
                    title: "Hidden multiday note",
                    date: dayTwo,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: dayTwo,
                    calendar: calendar
                )
            ]
        )
    }

    func generateScenarioSpreadNavigator(
        calendar: Calendar,
        today: Date
    ) -> GeneratedData {
        let marchYear = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? today
        let marchMonth = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? today
        let marchTenth = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? today
        let marchTwenty = calendar.date(from: DateComponents(year: 2026, month: 3, day: 20)) ?? today
        let marchTwentyTwo = calendar.date(from: DateComponents(year: 2026, month: 3, day: 22)) ?? today
        let marchTwentyNine = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)) ?? today
        let marchThirtyOne = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31)) ?? today
        let legacyYear = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? today

        return GeneratedData(
            spreads: [
                spread(.year, marchYear, calendar: calendar),
                spread(.month, marchMonth, calendar: calendar),
                spread(.day, marchTenth, calendar: calendar),
                spread(.day, marchTwentyNine, calendar: calendar),
                spread(.day, marchThirtyOne, calendar: calendar),
                DataModel.Spread(startDate: marchTwenty, endDate: marchTwentyTwo, calendar: calendar)
            ],
            tasks: [
                task(
                    title: "Navigator day task",
                    date: marchTwentyNine,
                    period: .day,
                    assignmentPeriod: .day,
                    assignmentDate: marchTwentyNine,
                    calendar: calendar
                ),
                task(
                    title: "Legacy traditional task",
                    date: legacyYear,
                    period: .year,
                    assignmentPeriod: .year,
                    assignmentDate: legacyYear,
                    calendar: calendar
                )
            ],
            events: [],
            notes: []
        )
    }

    private func spread(
        _ period: Period,
        _ date: Date,
        calendar: Calendar
    ) -> DataModel.Spread {
        DataModel.Spread(period: period, date: date, calendar: calendar)
    }

    private func task(
        title: String,
        date: Date,
        period: Period,
        assignmentPeriod: Period? = nil,
        assignmentDate: Date? = nil,
        status: DataModel.Task.Status = .open,
        calendar: Calendar
    ) -> DataModel.Task {
        let assignments: [TaskAssignment]
        if let assignmentPeriod, let assignmentDate {
            assignments = [
                TaskAssignment(
                    period: assignmentPeriod,
                    date: assignmentPeriod.normalizeDate(assignmentDate, calendar: calendar),
                    status: status == .complete ? .complete : .open
                )
            ]
        } else {
            assignments = []
        }

        return DataModel.Task(
            title: title,
            date: date,
            period: period,
            status: status,
            assignments: assignments
        )
    }

    private func note(
        title: String,
        date: Date,
        period: Period,
        assignmentPeriod: Period? = nil,
        assignmentDate: Date? = nil,
        calendar: Calendar
    ) -> DataModel.Note {
        let assignments: [NoteAssignment]
        if let assignmentPeriod, let assignmentDate {
            assignments = [
                NoteAssignment(
                    period: assignmentPeriod,
                    date: assignmentPeriod.normalizeDate(assignmentDate, calendar: calendar),
                    status: .active
                )
            ]
        } else {
            assignments = []
        }

        return DataModel.Note(
            title: title,
            content: "\(title) content",
            date: date,
            period: period,
            assignments: assignments
        )
    }

    private func futureScenarioDay(from today: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 8, to: today) ?? today
    }
}
#endif
