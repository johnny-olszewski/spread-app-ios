import Foundation

protocol JournalDataModelBuilder {
    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel
}

struct ConventionalJournalDataModelBuilder: JournalDataModelBuilder {
    let calendar: Calendar

    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        var model: JournalDataModel = [:]

        for spread in spreads {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)
            var spreadData = SpreadDataModel(spread: spread)
            spreadData.tasks = tasksForSpread(spread, tasks: tasks)
            spreadData.notes = notesForSpread(spread, notes: notes)
            spreadData.events = events.filter { spreadService.eventAppearsOnSpread($0, spread: spread) }

            if model[spread.period] == nil {
                model[spread.period] = [:]
            }
            model[spread.period]?[normalizedDate] = spreadData
        }

        return model
    }

    private func tasksForSpread(_ spread: DataModel.Spread, tasks: [DataModel.Task]) -> [DataModel.Task] {
        if spread.period == .multiday {
            return tasks.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return tasks.filter { hasSpreadAssociation($0, for: spread) }
    }

    private func notesForSpread(_ spread: DataModel.Spread, notes: [DataModel.Note]) -> [DataModel.Note] {
        if spread.period == .multiday {
            return notes.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return notes.filter { hasSpreadAssociation($0, for: spread) }
    }

    private func entryDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    private func hasSpreadAssociation(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    private func hasSpreadAssociation(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }
}

struct TraditionalJournalDataModelBuilder: JournalDataModelBuilder {
    let calendar: Calendar

    private var traditionalSpreadService: TraditionalSpreadService {
        TraditionalSpreadService(calendar: calendar)
    }

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        var model: JournalDataModel = [:]
        let years = traditionalSpreadService.yearsWithEntries(tasks: tasks, notes: notes, events: events)
        var virtualSpreads: [(period: Period, date: Date)] = []

        for yearDate in years {
            virtualSpreads.append((.year, yearDate))
        }

        for yearDate in years {
            let months = traditionalSpreadService.monthsWithEntries(
                inYear: yearDate,
                tasks: tasks,
                notes: notes,
                events: events
            )
            for monthDate in months {
                virtualSpreads.append((.month, monthDate))
            }
        }

        let allMonths = years.flatMap {
            traditionalSpreadService.monthsWithEntries(
                inYear: $0,
                tasks: tasks,
                notes: notes,
                events: events
            )
        }

        for monthDate in allMonths {
            let days = traditionalSpreadService.daysWithEntries(
                inMonth: monthDate,
                tasks: tasks,
                notes: notes,
                events: events
            )
            for dayDate in days {
                virtualSpreads.append((.day, dayDate))
            }
        }

        for (period, date) in virtualSpreads {
            let normalizedDate = period.normalizeDate(date, calendar: calendar)
            let spreadData = traditionalSpreadService.virtualSpreadDataModel(
                period: period,
                date: normalizedDate,
                tasks: tasks,
                notes: notes,
                events: events
            )

            if model[period] == nil {
                model[period] = [:]
            }
            model[period]?[normalizedDate] = spreadData
        }

        return model
    }
}
