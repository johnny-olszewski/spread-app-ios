import Foundation

struct MonthSpreadContentModel {
    let monthEntries: [any Entry]
    let daySections: [MonthSpreadDaySectionModel]
    let calendarActionsByDate: [Date: MonthSpreadCalendarDayAction]
}

enum MonthSpreadCalendarDayAction: Equatable {
    case view(DataModel.Spread)
    case revealSection(Date)
}

struct MonthSpreadDaySectionModel: Identifiable {
    let date: Date
    let entries: [any Entry]

    var id: Date { date }
}

@MainActor
enum MonthSpreadContentSupport {
    static func model(
        for spread: DataModel.Spread,
        spreadDataModel: SpreadDataModel,
        spreads: [DataModel.Spread],
        calendar: Calendar
    ) -> MonthSpreadContentModel {
        let entries = monthEntriesAndDaySectionCandidates(from: spreadDataModel)
        let monthEntries = entries
            .filter(isMonthSectionEntry)
            .sorted { lhs, rhs in
                sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
            }

        let groupedDayEntries = Dictionary(grouping: entries.filter(isDaySectionEntry)) { entry in
            Period.day.normalizeDate(entryDate(for: entry), calendar: calendar)
        }

        let explicitDaySpreads = spreads
            .filter { spread in
                spread.period == .day &&
                Period.month.normalizeDate(spread.date, calendar: calendar) ==
                    Period.month.normalizeDate(spreadDataModel.spread.date, calendar: calendar)
            }
            .sorted { lhs, rhs in
                Period.day.normalizeDate(lhs.date, calendar: calendar) <
                    Period.day.normalizeDate(rhs.date, calendar: calendar)
            }

        let explicitDaySpreadsByDate = explicitDaySpreads.reduce(into: [Date: DataModel.Spread]()) { result, spread in
            let normalizedDate = Period.day.normalizeDate(spread.date, calendar: calendar)
            result[normalizedDate] = spread
        }

        let sectionDates = groupedDayEntries.keys
            .filter { explicitDaySpreadsByDate[$0] == nil }
            .sorted()

        let daySections = sectionDates.map { date in
            return MonthSpreadDaySectionModel(
                date: date,
                entries: (groupedDayEntries[date] ?? []).sorted { lhs, rhs in
                    sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
                }
            )
        }

        var calendarActionsByDate = sectionDates.reduce(into: [Date: MonthSpreadCalendarDayAction]()) { result, date in
            result[date] = .revealSection(date)
        }

        for (date, spread) in explicitDaySpreadsByDate {
            calendarActionsByDate[date] = .view(spread)
        }

        return MonthSpreadContentModel(
            monthEntries: monthEntries,
            daySections: daySections,
            calendarActionsByDate: calendarActionsByDate
        )
    }

    private static func monthEntriesAndDaySectionCandidates(
        from spreadDataModel: SpreadDataModel
    ) -> [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: spreadDataModel.tasks)
        entries.append(contentsOf: spreadDataModel.notes)
        return entries
    }

    private static func isMonthSectionEntry(_ entry: any Entry) -> Bool {
        if let task = entry as? DataModel.Task {
            return task.period == .month
        }

        if let note = entry as? DataModel.Note {
            return note.period == .month
        }

        return false
    }

    private static func isDaySectionEntry(_ entry: any Entry) -> Bool {
        if let task = entry as? DataModel.Task {
            return task.period == .day
        }

        if let note = entry as? DataModel.Note {
            return note.period == .day
        }

        return false
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

    private static func sortKey(
        for entry: any Entry,
        calendar: Calendar
    ) -> (Date, Int, Date, UUID) {
        if let task = entry as? DataModel.Task {
            return (
                task.period.normalizeDate(task.date, calendar: calendar),
                entryTypeSortOrder(task.entryType),
                task.createdDate,
                task.id
            )
        }

        if let note = entry as? DataModel.Note {
            return (
                note.period.normalizeDate(note.date, calendar: calendar),
                entryTypeSortOrder(note.entryType),
                note.createdDate,
                note.id
            )
        }

        return (.distantFuture, entryTypeSortOrder(entry.entryType), entry.createdDate, entry.id)
    }

    private static func entryTypeSortOrder(_ type: EntryType) -> Int {
        switch type {
        case .task:
            return 0
        case .note:
            return 1
        case .event:
            return 2
        }
    }
}
