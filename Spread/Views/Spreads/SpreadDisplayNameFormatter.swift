import Foundation

struct SpreadDisplayName: Equatable {
    let primary: String
    let canonicalTitle: String
    let canonicalSubtitle: String?
    let canonicalContext: String?
    let isPersonalized: Bool

    var secondaryForHeader: String? {
        isPersonalized ? canonicalContext : canonicalSubtitle
    }
}

struct SpreadDisplayNameFormatter {
    let calendar: Calendar
    let today: Date
    let firstWeekday: FirstWeekday

    func display(for spread: DataModel.Spread, allowsPersonalization: Bool = true) -> SpreadDisplayName {
        let canonicalTitle = Self.canonicalTitle(for: spread, calendar: calendar)
        let canonicalSubtitle = Self.canonicalSubtitle(for: spread, calendar: calendar)
        let canonicalContext = Self.canonicalContext(
            title: canonicalTitle,
            subtitle: canonicalSubtitle,
            period: spread.period
        )

        guard allowsPersonalization else {
            return SpreadDisplayName(
                primary: canonicalTitle,
                canonicalTitle: canonicalTitle,
                canonicalSubtitle: canonicalSubtitle,
                canonicalContext: canonicalContext,
                isPersonalized: false
            )
        }

        if let customName = Self.sanitizedCustomName(spread.customName) {
            return SpreadDisplayName(
                primary: customName,
                canonicalTitle: canonicalTitle,
                canonicalSubtitle: canonicalSubtitle,
                canonicalContext: canonicalContext,
                isPersonalized: true
            )
        }

        if spread.usesDynamicName,
           let dynamicName = dynamicName(for: spread),
           dynamicName != canonicalTitle {
            return SpreadDisplayName(
                primary: dynamicName,
                canonicalTitle: canonicalTitle,
                canonicalSubtitle: canonicalSubtitle,
                canonicalContext: canonicalContext,
                isPersonalized: true
            )
        }

        return SpreadDisplayName(
            primary: canonicalTitle,
            canonicalTitle: canonicalTitle,
            canonicalSubtitle: canonicalSubtitle,
            canonicalContext: canonicalContext,
            isPersonalized: false
        )
    }

    static func sanitizedCustomName(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func canonicalTitle(for spread: DataModel.Spread, calendar: Calendar) -> String {
        switch spread.period {
        case .year:
            return String(calendar.component(.year, from: spread.date))
        case .month:
            return monthTitle(for: spread.date, calendar: calendar)
        case .day:
            return dayTitle(for: spread.date, calendar: calendar)
        case .multiday:
            return multidayTitle(for: spread, calendar: calendar)
        }
    }

    static func canonicalSubtitle(for spread: DataModel.Spread, calendar: Calendar) -> String? {
        switch spread.period {
        case .year:
            return nil
        case .month:
            return String(calendar.component(.year, from: spread.date))
        case .day:
            return weekdayTitle(for: spread.date, calendar: calendar)
        case .multiday:
            return multidaySubtitle(for: spread, calendar: calendar)
        }
    }

    private func dynamicName(for spread: DataModel.Spread) -> String? {
        switch spread.period {
        case .year:
            return relativeName(
                spreadDate: Period.year.normalizeDate(spread.date, calendar: calendar),
                currentDate: Period.year.normalizeDate(today, calendar: calendar),
                component: .year,
                previous: "Last year",
                current: "This year",
                next: "Next year"
            )
        case .month:
            return relativeName(
                spreadDate: Period.month.normalizeDate(spread.date, calendar: calendar),
                currentDate: Period.month.normalizeDate(today, calendar: calendar),
                component: .month,
                previous: "Last month",
                current: "This month",
                next: "Next month"
            )
        case .day:
            return relativeName(
                spreadDate: Period.day.normalizeDate(spread.date, calendar: calendar),
                currentDate: Period.day.normalizeDate(today, calendar: calendar),
                component: .day,
                previous: "Yesterday",
                current: "Today",
                next: "Tomorrow"
            )
        case .multiday:
            return multidayDynamicName(for: spread)
        }
    }

    private func relativeName(
        spreadDate: Date,
        currentDate: Date,
        component: Calendar.Component,
        previous: String,
        current: String,
        next: String
    ) -> String? {
        if spreadDate == currentDate {
            return current
        }
        if calendar.date(byAdding: component, value: -1, to: currentDate) == spreadDate {
            return previous
        }
        if calendar.date(byAdding: component, value: 1, to: currentDate) == spreadDate {
            return next
        }
        return nil
    }

    private func multidayDynamicName(for spread: DataModel.Spread) -> String? {
        guard let startDate = spread.startDate, let endDate = spread.endDate else { return nil }
        let normalizedStart = Period.day.normalizeDate(startDate, calendar: calendar)
        let normalizedEnd = Period.day.normalizeDate(endDate, calendar: calendar)

        if let label = weekDynamicName(startDate: normalizedStart, endDate: normalizedEnd) {
            return label
        }
        return weekendDynamicName(startDate: normalizedStart, endDate: normalizedEnd)
    }

    private func weekDynamicName(startDate: Date, endDate: Date) -> String? {
        guard let thisWeekStart = today.firstDayOfWeek(calendar: calendar, firstWeekday: firstWeekday),
              let thisWeekEnd = today.lastDayOfWeek(calendar: calendar, firstWeekday: firstWeekday) else {
            return nil
        }

        let candidates: [(String, Date, Date?)] = [
            ("Last week", calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart, calendar.date(byAdding: .day, value: -7, to: thisWeekEnd)),
            ("This week", thisWeekStart, thisWeekEnd),
            ("Next week", calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? thisWeekStart, calendar.date(byAdding: .day, value: 7, to: thisWeekEnd))
        ]

        return candidates.first { _, candidateStart, candidateEnd in
            startDate == candidateStart && endDate == candidateEnd
        }?.0
    }

    private func weekendDynamicName(startDate: Date, endDate: Date) -> String? {
        guard let thisSaturday = nextWeekday(7, onOrAfter: today),
              let thisSunday = calendar.date(byAdding: .day, value: 1, to: thisSaturday) else {
            return nil
        }

        let candidates: [(String, Date?, Date?)] = [
            ("Last weekend", calendar.date(byAdding: .day, value: -7, to: thisSaturday), calendar.date(byAdding: .day, value: -7, to: thisSunday)),
            ("This weekend", thisSaturday, thisSunday),
            ("Next weekend", calendar.date(byAdding: .day, value: 7, to: thisSaturday), calendar.date(byAdding: .day, value: 7, to: thisSunday))
        ]

        return candidates.first { _, candidateStart, candidateEnd in
            guard let candidateStart, let candidateEnd else { return false }
            return startDate == Period.day.normalizeDate(candidateStart, calendar: calendar) &&
                endDate == Period.day.normalizeDate(candidateEnd, calendar: calendar)
        }?.0
    }

    private func nextWeekday(_ weekday: Int, onOrAfter date: Date) -> Date? {
        let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
        let currentWeekday = calendar.component(.weekday, from: normalizedDate)
        let offset = (weekday - currentWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: normalizedDate)
    }

    private static func canonicalContext(title: String, subtitle: String?, period: Period) -> String? {
        guard let subtitle, !subtitle.isEmpty else { return title }
        switch period {
        case .month:
            return "\(title) \(subtitle)"
        case .day, .multiday:
            return title
        case .year:
            return title
        }
    }

    private static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    private static func dayTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private static func multidayTitle(for spread: DataModel.Spread, calendar: Calendar) -> String {
        guard let startDate = spread.startDate, let endDate = spread.endDate else {
            return "Multiday"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "d MMM"

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    private static func weekdayTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private static func multidaySubtitle(for spread: DataModel.Spread, calendar: Calendar) -> String {
        guard let startDate = spread.startDate, let endDate = spread.endDate else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE"

        let startWeekday = formatter.string(from: startDate)
        let endWeekday = formatter.string(from: endDate)
        if startWeekday == endWeekday {
            return startWeekday
        }
        return "\(startWeekday) - \(endWeekday)"
    }
}
