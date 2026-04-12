import Foundation

enum SpreadMonthCalendarSupport {
    static func monthDayDates(monthDate: Date, calendar: Calendar) -> [Date] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }

        var dates: [Date] = []
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    static func conventionalEntryCountsByDate(
        monthDate: Date,
        spreads: [DataModel.Spread],
        dataModel: JournalDataModel,
        calendar: Calendar
    ) -> [Date: Int] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)

        return spreads.reduce(into: [:]) { result, spread in
            guard spread.period == .day else { return }
            let normalizedDate = Period.day.normalizeDate(spread.date, calendar: calendar)
            guard Period.month.normalizeDate(normalizedDate, calendar: calendar) == monthStart else { return }

            let count = (dataModel[.day]?[normalizedDate]?.tasks.count ?? 0) +
                (dataModel[.day]?[normalizedDate]?.notes.count ?? 0)
            result[normalizedDate] = count
        }
    }

    static func traditionalEntryCountsByDate(
        monthDate: Date,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event],
        calendar: Calendar
    ) -> [Date: Int] {
        let service = TraditionalSpreadService(calendar: calendar)

        return monthDayDates(monthDate: monthDate, calendar: calendar).reduce(into: [:]) { result, date in
            let model = service.virtualSpreadDataModel(
                period: .day,
                date: date,
                tasks: tasks,
                notes: notes,
                events: events
            )
            result[Period.day.normalizeDate(date, calendar: calendar)] = model.tasks.count + model.notes.count
        }
    }
}
