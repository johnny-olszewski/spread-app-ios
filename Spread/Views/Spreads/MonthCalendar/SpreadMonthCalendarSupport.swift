import Foundation

struct SpreadMonthCalendarDayState: Equatable {
    let hasExplicitDaySpread: Bool
    let contentCount: Int
}

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

    static func conventionalDayStateByDate(
        monthDate: Date,
        spreads: [DataModel.Spread],
        dataModel: JournalDataModel,
        monthSpreadDataModel: SpreadDataModel?,
        calendar: Calendar
    ) -> [Date: SpreadMonthCalendarDayState] {
        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        let fallbackMonthContentCounts = currentMonthContentCounts(
            monthSpreadDataModel: monthSpreadDataModel,
            calendar: calendar
        )

        return spreads.reduce(into: [:]) { result, spread in
            guard spread.period == .day else { return }
            let normalizedDate = Period.day.normalizeDate(spread.date, calendar: calendar)
            guard Period.month.normalizeDate(normalizedDate, calendar: calendar) == monthStart else { return }

            let explicitDayContentCount = (dataModel[.day]?[normalizedDate]?.tasks.count ?? 0) +
                (dataModel[.day]?[normalizedDate]?.notes.count ?? 0)
            let fallbackMonthContentCount = fallbackMonthContentCounts[normalizedDate] ?? 0

            result[normalizedDate] = SpreadMonthCalendarDayState(
                hasExplicitDaySpread: true,
                contentCount: max(explicitDayContentCount, fallbackMonthContentCount)
            )
        }
        .merging(
            fallbackMonthContentCounts.reduce(into: [:]) { result, element in
                let (date, count) = element
                result[date] = SpreadMonthCalendarDayState(
                    hasExplicitDaySpread: false,
                    contentCount: count
                )
            }
        ) { explicitState, fallbackState in
            SpreadMonthCalendarDayState(
                hasExplicitDaySpread: explicitState.hasExplicitDaySpread,
                contentCount: max(explicitState.contentCount, fallbackState.contentCount)
            )
        }
    }

    static func traditionalDayStateByDate(
        monthDate: Date,
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event],
        calendar: Calendar
    ) -> [Date: SpreadMonthCalendarDayState] {
        let service = TraditionalSpreadService(calendar: calendar)

        return monthDayDates(monthDate: monthDate, calendar: calendar).reduce(into: [:]) { result, date in
            let model = service.virtualSpreadDataModel(
                period: .day,
                date: date,
                tasks: tasks,
                notes: notes,
                events: events
            )
            result[Period.day.normalizeDate(date, calendar: calendar)] = SpreadMonthCalendarDayState(
                hasExplicitDaySpread: true,
                contentCount: model.tasks.count + model.notes.count
            )
        }
    }

    private static func currentMonthContentCounts(
        monthSpreadDataModel: SpreadDataModel?,
        calendar: Calendar
    ) -> [Date: Int] {
        guard let monthSpreadDataModel else { return [:] }

        let dayTasks = monthSpreadDataModel.tasks.filter { $0.period == .day }
        let dayNotes = monthSpreadDataModel.notes.filter { $0.period == .day }

        return (dayTasks as [any Entry] + dayNotes as [any Entry]).reduce(into: [:]) { result, entry in
            let date = Period.day.normalizeDate(entryDate(for: entry), calendar: calendar)
            result[date, default: 0] += 1
        }
    }

    private static func entryDate(for entry: any Entry) -> Date {
        if let task = entry as? DataModel.Task {
            return task.date
        }

        if let note = entry as? DataModel.Note {
            return note.date
        }

        return entry.createdDate
    }
}
