import Foundation
import SwiftUI

struct YearSpreadContentModel {
    let yearEntries: [any Entry]
    let monthCards: [YearSpreadMonthCardModel]
}

struct YearSpreadMonthCardPreview: Identifiable {
    let entry: any Entry
    let contextualLabel: String?

    var id: UUID { entry.id }
}

enum YearSpreadMonthCardAction: Equatable {
    case view(DataModel.Spread)
    case create(Date)

    var title: String {
        switch self {
        case .view:
            return "View Spread"
        case .create:
            return "Create Spread"
        }
    }
}

struct YearSpreadMonthCardModel: Identifiable {
    let monthDate: Date
    let visualState: MultidayDayCardVisualState
    let explicitMonthSpread: DataModel.Spread?
    let previews: [YearSpreadMonthCardPreview]
    let overflowCount: Int
    let action: YearSpreadMonthCardAction

    var id: Date { monthDate }
}

@MainActor
enum YearSpreadContentSupport {
    static let previewThreshold = 3

    static func model(
        for spread: DataModel.Spread,
        spreadDataModel: SpreadDataModel,
        spreads: [DataModel.Spread],
        today: Date,
        calendar: Calendar
    ) -> YearSpreadContentModel {
        let allEntries = yearEntriesAndMonthCardCandidates(from: spreadDataModel)
        let yearEntries = allEntries
            .filter(isTopYearSectionEntry)
            .sorted { lhs, rhs in
                sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
            }

        let monthCards = monthDates(in: spread.date, calendar: calendar).map { monthDate in
            monthCard(
                for: monthDate,
                entries: allEntries,
                spreads: spreads,
                today: today,
                calendar: calendar
            )
        }

        return YearSpreadContentModel(
            yearEntries: yearEntries,
            monthCards: monthCards
        )
    }

    static func monthCard(
        for monthDate: Date,
        entries: [any Entry],
        spreads: [DataModel.Spread],
        today: Date,
        calendar: Calendar
    ) -> YearSpreadMonthCardModel {
        let normalizedMonth = Period.month.normalizeDate(monthDate, calendar: calendar)
        let explicitMonthSpread = spreads.first(where: { spread in
            spread.period == .month &&
            Period.month.normalizeDate(spread.date, calendar: calendar) == normalizedMonth
        })

        let allPreviews = entries
            .filter { entry in
                guard let monthCandidate = monthCardMonthDate(for: entry, calendar: calendar) else {
                    return false
                }
                return monthCandidate == normalizedMonth
            }
            .sorted { lhs, rhs in
                sortKey(for: lhs, calendar: calendar) < sortKey(for: rhs, calendar: calendar)
            }
            .map { entry in
                YearSpreadMonthCardPreview(
                    entry: entry,
                    contextualLabel: contextualLabel(for: entry, calendar: calendar)
                )
            }

        let visiblePreviews = Array(allPreviews.prefix(previewThreshold))
        let overflowCount = max(0, allPreviews.count - visiblePreviews.count)
        let isCurrentMonth = calendar.isDate(normalizedMonth, equalTo: today, toGranularity: .month)
        let visualState = MultidayDayCardSupport.visualState(
            isToday: isCurrentMonth,
            isCreated: explicitMonthSpread != nil
        )

        return YearSpreadMonthCardModel(
            monthDate: normalizedMonth,
            visualState: visualState,
            explicitMonthSpread: explicitMonthSpread,
            previews: visiblePreviews,
            overflowCount: overflowCount,
            action: explicitMonthSpread.map(YearSpreadMonthCardAction.view) ?? .create(normalizedMonth)
        )
    }

    static func contextualLabel(
        for entry: any Entry,
        calendar: Calendar
    ) -> String? {
        if let task = entry as? DataModel.Task, task.period == .day {
            return String(calendar.component(.day, from: task.date))
        }

        if let note = entry as? DataModel.Note, note.period == .day {
            return String(calendar.component(.day, from: note.date))
        }

        return nil
    }

    private static func yearEntriesAndMonthCardCandidates(
        from spreadDataModel: SpreadDataModel
    ) -> [any Entry] {
        var entries: [any Entry] = []
        entries.append(contentsOf: spreadDataModel.tasks)
        entries.append(contentsOf: spreadDataModel.notes)
        return entries
    }

    private static func isTopYearSectionEntry(_ entry: any Entry) -> Bool {
        if let task = entry as? DataModel.Task {
            return task.period == .year
        }

        if let note = entry as? DataModel.Note {
            return note.period == .year
        }

        return false
    }

    private static func monthCardMonthDate(
        for entry: any Entry,
        calendar: Calendar
    ) -> Date? {
        if let task = entry as? DataModel.Task,
           task.period == .month || task.period == .day {
            return Period.month.normalizeDate(task.date, calendar: calendar)
        }

        if let note = entry as? DataModel.Note,
           note.period == .month || note.period == .day {
            return Period.month.normalizeDate(note.date, calendar: calendar)
        }

        return nil
    }

    private static func monthDates(
        in yearDate: Date,
        calendar: Calendar
    ) -> [Date] {
        let year = calendar.component(.year, from: yearDate)
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
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
