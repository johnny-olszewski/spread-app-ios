import Foundation

struct SpreadHeaderNavigatorModel {
    enum Mode {
        case conventional
        case traditional
    }

    enum Selection {
        case conventional(DataModel.Spread)
        case traditionalYear(Date)
        case traditionalMonth(Date)
        case traditionalDay(Date)
    }

    struct YearPage: Identifiable {
        let year: Int
        let spreads: [DataModel.Spread]
        let months: [MonthRow]

        var id: Int { year }
    }

    struct MonthRow: Identifiable {
        let date: Date
        let explicitSpread: DataModel.Spread?
        let isDerived: Bool
        let monthSelection: Selection?
        let dayTargetsByDate: [Date: [SelectionTarget]]
        let dayStateByDate: [Date: SpreadMonthCalendarDayState]

        var id: Date { date }
        var canViewMonth: Bool { monthSelection != nil }

        func targets(for date: Date, calendar: Calendar) -> [SelectionTarget] {
            dayTargetsByDate[Period.day.normalizeDate(date, calendar: calendar), default: []]
        }

        func dayState(for date: Date, calendar: Calendar) -> SpreadMonthCalendarDayState {
            dayStateByDate[
                Period.day.normalizeDate(date, calendar: calendar),
                default: .init(hasExplicitDaySpread: false, contentCount: 0)
            ]
        }
    }

    struct SelectionTarget: Identifiable {
        let id: String
        let selection: Selection
        let title: String
        let isMultiday: Bool
    }

    let mode: Mode
    let calendar: Calendar
    let today: Date
    var firstWeekday: FirstWeekday = .systemDefault
    let spreads: [DataModel.Spread]
    let tasks: [DataModel.Task]
    let notes: [DataModel.Note]
    let events: [DataModel.Event]

    func initialYear(for currentSpread: DataModel.Spread) -> Int {
        calendar.component(.year, from: currentSpread.date)
    }

    func initialExpandedMonth(for currentSpread: DataModel.Spread) -> Date? {
        switch currentSpread.period {
        case .month, .day, .multiday:
            return Period.month.normalizeDate(currentSpread.date, calendar: calendar)
        case .year:
            return nil
        }
    }

    func yearPages() -> [YearPage] {
        yearsInNavigationOrder().map { year in
            let yearSpreads = spreads.filter { spreadTouchesYear($0, year: year) }
            return YearPage(
                year: year,
                spreads: yearSpreads,
                months: months(in: year)
            )
        }
    }

    func months(in year: Int) -> [MonthRow] {
        switch mode {
        case .conventional:
            return conventionalMonthRows(in: year)
        case .traditional:
            return traditionalMonthRows(in: year)
        }
    }

    func selectionTarget(for monthRow: MonthRow) -> Selection? {
        monthRow.monthSelection
    }

    func isCurrent(monthRow: MonthRow, currentSpread: DataModel.Spread) -> Bool {
        currentSpread.period == .month &&
        calendar.isDate(currentSpread.date, equalTo: monthRow.date, toGranularity: .month)
    }

    func isCurrent(date: Date, currentSpread: DataModel.Spread) -> Bool {
        switch currentSpread.period {
        case .day:
            return calendar.isDate(currentSpread.date, inSameDayAs: date)
        default:
            return false
        }
    }

    func yearsInNavigationOrder() -> [Int] {
        switch mode {
        case .conventional:
            return conventionalYears()
        case .traditional:
            return traditionalYears()
        }
    }

    private func conventionalYears() -> [Int] {
        var allYears = Set<Int>()
        for spread in spreads {
            allYears.formUnion(yearsTouched(by: spread))
        }
        return allYears.sorted()
    }

    private func traditionalYears() -> [Int] {
        let currentYear = calendar.component(.year, from: today)
        let maxYear = currentYear + 10
        let earliestYear = earliestTraditionalYear() ?? currentYear
        return Array(earliestYear...maxYear)
    }

    private func conventionalMonthRows(in year: Int) -> [MonthRow] {
        let explicitMonths = Dictionary(uniqueKeysWithValues: spreads.filter {
            $0.period == .month && calendar.component(.year, from: $0.date) == year
        }.map {
            (calendar.component(.month, from: $0.date), $0)
        })

        var visibleMonths = Set(explicitMonths.keys)
        for spread in spreads where spread.period == .day || spread.period == .multiday {
            visibleMonths.formUnion(monthsTouched(by: spread, in: year))
        }

        return visibleMonths.sorted().compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                return nil
            }

            return MonthRow(
                date: date,
                explicitSpread: explicitMonths[month],
                isDerived: explicitMonths[month] == nil,
                monthSelection: explicitMonths[month].map(Selection.conventional),
                dayTargetsByDate: conventionalDayTargetsByDate(year: year, month: month),
                dayStateByDate: conventionalDayStateByDate(year: year, month: month)
            )
        }
    }

    private func traditionalMonthRows(in year: Int) -> [MonthRow] {
        (1...12).compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                return nil
            }

            return MonthRow(
                date: date,
                explicitSpread: nil,
                isDerived: false,
                monthSelection: .traditionalMonth(date),
                dayTargetsByDate: traditionalDayTargetsByDate(year: year, month: month),
                dayStateByDate: traditionalDayStateByDate(year: year, month: month)
            )
        }
    }

    private func conventionalDayStateByDate(year: Int, month: Int) -> [Date: SpreadMonthCalendarDayState] {
        guard let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthDate) else {
            return [:]
        }

        let monthStart = Period.month.normalizeDate(monthDate, calendar: calendar)
        let yearStart = Period.year.normalizeDate(monthDate, calendar: calendar)
        let explicitDayDates = Set(
            spreads
                .filter {
                    $0.period == .day &&
                    Period.month.normalizeDate($0.date, calendar: calendar) == monthStart
                }
                .map { Period.day.normalizeDate($0.date, calendar: calendar) }
        )

        let contentCounts = conventionalDayContentCounts(
            yearStart: yearStart,
            monthStart: monthStart
        )

        return dayRange.reduce(into: [:]) { result, day in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return
            }
            let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
            let contentCount = contentCounts[normalizedDate, default: 0]
            let hasExplicitDaySpread = explicitDayDates.contains(normalizedDate)

            guard hasExplicitDaySpread || contentCount > 0 else { return }
            result[normalizedDate] = SpreadMonthCalendarDayState(
                hasExplicitDaySpread: hasExplicitDaySpread,
                contentCount: contentCount
            )
        }
    }

    private func conventionalDayTargetsByDate(year: Int, month: Int) -> [Date: [SelectionTarget]] {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return [:]
        }

        var result: [Date: [SelectionTarget]] = [:]

        for day in dayRange {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }
            let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
            var targets: [SelectionTarget] = []

            if let daySpread = spreads.first(where: {
                $0.period == .day && calendar.isDate($0.date, inSameDayAs: normalizedDate)
            }) {
                targets.append(
                    SelectionTarget(
                        id: "day-\(normalizedDate.timeIntervalSinceReferenceDate)",
                        selection: .conventional(daySpread),
                        title: "View Day",
                        isMultiday: false
                    )
                )
            }

            let multidayTargets = spreads
                .filter { $0.period == .multiday && spread($0, overlapsDay: normalizedDate) }
                .sorted { lhs, rhs in
                    let lhsStart = lhs.startDate ?? lhs.date
                    let rhsStart = rhs.startDate ?? rhs.date
                    if lhsStart == rhsStart {
                        return lhs.displayLabel(calendar: calendar) < rhs.displayLabel(calendar: calendar)
                    }
                    return lhsStart < rhsStart
                }
                .map { spread in
                    SelectionTarget(
                        id: "multiday-\(spread.id.uuidString.lowercased())-\(normalizedDate.timeIntervalSinceReferenceDate)",
                        selection: .conventional(spread),
                        title: displayName(for: spread),
                        isMultiday: true
                    )
                }

            targets.append(contentsOf: multidayTargets)
            if !targets.isEmpty {
                result[normalizedDate] = targets
            }
        }

        return result
    }

    private func traditionalDayStateByDate(year: Int, month: Int) -> [Date: SpreadMonthCalendarDayState] {
        guard let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return [:]
        }

        return SpreadMonthCalendarSupport.traditionalDayStateByDate(
            monthDate: monthDate,
            tasks: tasks,
            notes: notes,
            events: events,
            calendar: calendar
        )
    }

    private func traditionalDayTargetsByDate(year: Int, month: Int) -> [Date: [SelectionTarget]] {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return [:]
        }

        var result: [Date: [SelectionTarget]] = [:]
        for day in dayRange {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                continue
            }
            let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
            result[normalizedDate] = [
                SelectionTarget(
                    id: "traditional-day-\(normalizedDate.timeIntervalSinceReferenceDate)",
                    selection: .traditionalDay(normalizedDate),
                    title: "View Day",
                    isMultiday: false
                )
            ]
        }
        return result
    }

    private func yearsTouched(by spread: DataModel.Spread) -> Set<Int> {
        let startDate = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: calendar)
        let endDate = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar)
        let startYear = calendar.component(.year, from: startDate)
        let endYear = calendar.component(.year, from: endDate)

        guard startYear <= endYear else { return [startYear] }
        return Set(startYear...endYear)
    }

    private func monthsTouched(by spread: DataModel.Spread, in year: Int) -> Set<Int> {
        let startDate = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: calendar)
        let endDate = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

        guard endDate >= startOfYear, startDate <= endOfYear else { return [] }

        var months = Set<Int>()
        var cursor = calendar.date(from: DateComponents(
            year: max(year, calendar.component(.year, from: startDate)),
            month: max(1, calendar.component(.month, from: startDate)),
            day: 1
        ))!

        let boundedEndDate = min(endDate, endOfYear)
        while cursor <= boundedEndDate {
            if calendar.component(.year, from: cursor) == year {
                months.insert(calendar.component(.month, from: cursor))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return months
    }

    private func spreadTouchesYear(_ spread: DataModel.Spread, year: Int) -> Bool {
        yearsTouched(by: spread).contains(year)
    }

    private func spread(_ spread: DataModel.Spread, overlapsDay date: Date) -> Bool {
        let startDate = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: calendar)
        let endDate = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar)
        let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    private func displayName(for spread: DataModel.Spread) -> String {
        SpreadDisplayNameFormatter(
            calendar: calendar,
            today: today,
            firstWeekday: firstWeekday
        )
        .display(for: spread, allowsPersonalization: mode == .conventional)
        .primary
    }

    private func conventionalDayContentCounts(
        yearStart: Date,
        monthStart: Date
    ) -> [Date: Int] {
        var counts: [Date: Int] = [:]

        for task in tasks {
            guard let assignment = currentAssignment(for: task) else { continue }
            countCurrentContent(
                entryDate: task.date,
                preferredPeriod: task.period,
                assignmentPeriod: assignment.period,
                assignmentDate: assignment.date,
                yearStart: yearStart,
                monthStart: monthStart,
                into: &counts
            )
        }

        for note in notes {
            guard let assignment = currentAssignment(for: note) else { continue }
            countCurrentContent(
                entryDate: note.date,
                preferredPeriod: note.period,
                assignmentPeriod: assignment.period,
                assignmentDate: assignment.date,
                yearStart: yearStart,
                monthStart: monthStart,
                into: &counts
            )
        }

        return counts
    }

    private func currentAssignment(for task: DataModel.Task) -> TaskAssignment? {
        task.assignments.first(where: { $0.status != .migrated })
    }

    private func currentAssignment(for note: DataModel.Note) -> NoteAssignment? {
        note.assignments.first(where: { $0.status != .migrated })
    }

    private func countCurrentContent(
        entryDate: Date,
        preferredPeriod: Period,
        assignmentPeriod: Period,
        assignmentDate: Date,
        yearStart: Date,
        monthStart: Date,
        into counts: inout [Date: Int]
    ) {
        let normalizedEntryDay = Period.day.normalizeDate(entryDate, calendar: calendar)

        switch assignmentPeriod {
        case .day:
            guard Period.month.normalizeDate(assignmentDate, calendar: calendar) == monthStart else { return }
            let normalizedAssignmentDay = Period.day.normalizeDate(assignmentDate, calendar: calendar)
            counts[normalizedAssignmentDay, default: 0] += 1

        case .month:
            guard Period.month.normalizeDate(assignmentDate, calendar: calendar) == monthStart,
                  preferredPeriod == .day,
                  Period.month.normalizeDate(normalizedEntryDay, calendar: calendar) == monthStart else {
                return
            }
            counts[normalizedEntryDay, default: 0] += 1

        case .year:
            guard Period.year.normalizeDate(assignmentDate, calendar: calendar) == yearStart,
                  preferredPeriod == .day,
                  Period.month.normalizeDate(normalizedEntryDay, calendar: calendar) == monthStart else {
                return
            }
            counts[normalizedEntryDay, default: 0] += 1

        case .multiday:
            break
        }
    }

    private func earliestTraditionalYear() -> Int? {
        var years: [Int] = []

        years.append(contentsOf: spreads.flatMap { Array(yearsTouched(by: $0)) })
        years.append(contentsOf: tasks.compactMap {
            $0.hasPreferredAssignment ? calendar.component(.year, from: $0.date) : nil
        })
        years.append(contentsOf: notes.map { calendar.component(.year, from: $0.date) })
        years.append(contentsOf: events.flatMap { event in
            [event.startDate, event.endDate].map { calendar.component(.year, from: $0) }
        })

        return years.min()
    }
}
