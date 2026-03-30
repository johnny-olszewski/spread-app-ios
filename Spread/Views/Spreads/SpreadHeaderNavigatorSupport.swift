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

    struct ExpansionState: Equatable {
        let expandedYear: Int?
        let expandedMonth: Date?
    }

    struct YearRow: Identifiable {
        let year: Int
        let explicitSpread: DataModel.Spread?
        let isDerived: Bool

        var id: Int { year }
        var canDirectSelect: Bool { explicitSpread != nil || explicitTraditionalSelection != nil }
        fileprivate let explicitTraditionalSelection: Date?
    }

    struct MonthRow: Identifiable {
        let date: Date
        let explicitSpread: DataModel.Spread?
        let isDerived: Bool

        var id: Date { date }
        var canDirectSelect: Bool { explicitSpread != nil || explicitTraditionalSelection != nil }
        fileprivate let explicitTraditionalSelection: Date?
    }

    struct MonthGridItem: Identifiable {
        enum Kind {
            case day(Date)
            case multiday(DataModel.Spread)
        }

        let kind: Kind
        fileprivate let calendar: Calendar

        var id: String {
            switch kind {
            case .day(let date):
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return String(
                    format: "day-%04d-%02d-%02d",
                    components.year ?? 0,
                    components.month ?? 0,
                    components.day ?? 0
                )
            case .multiday(let spread):
                return "multiday-\(spread.id.uuidString.lowercased())"
            }
        }

        var startDate: Date {
            switch kind {
            case .day(let date):
                return date
            case .multiday(let spread):
                return spread.startDate ?? spread.date
            }
        }

        var label: String {
            switch kind {
            case .day(let date):
                return String(calendar.component(.day, from: date))
            case .multiday(let spread):
                return spread.displayLabel(calendar: calendar)
            }
        }

        var isMultiday: Bool {
            if case .multiday = kind { return true }
            return false
        }
    }

    let mode: Mode
    let calendar: Calendar
    let today: Date
    let spreads: [DataModel.Spread]
    let tasks: [DataModel.Task]
    let notes: [DataModel.Note]
    let events: [DataModel.Event]

    func initialExpansion(for currentSpread: DataModel.Spread) -> ExpansionState {
        let year = calendar.component(.year, from: currentSpread.date)
        let monthDate = Period.month.normalizeDate(currentSpread.date, calendar: calendar)

        switch currentSpread.period {
        case .year:
            return ExpansionState(expandedYear: year, expandedMonth: nil)
        case .month, .day, .multiday:
            return ExpansionState(expandedYear: year, expandedMonth: monthDate)
        }
    }

    func toggledYear(_ year: Int, from state: ExpansionState) -> ExpansionState {
        if state.expandedYear == year {
            return ExpansionState(expandedYear: nil, expandedMonth: nil)
        }
        return ExpansionState(expandedYear: year, expandedMonth: nil)
    }

    func toggledMonth(_ monthDate: Date, in year: Int, from state: ExpansionState) -> ExpansionState {
        guard state.expandedYear == year else {
            return ExpansionState(expandedYear: year, expandedMonth: monthDate)
        }
        if state.expandedMonth == monthDate {
            return ExpansionState(expandedYear: year, expandedMonth: nil)
        }
        return ExpansionState(expandedYear: year, expandedMonth: monthDate)
    }

    func rootYears() -> [YearRow] {
        switch mode {
        case .conventional:
            return conventionalYearRows()
        case .traditional:
            return traditionalYearRows()
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

    func monthGridItems(year: Int, month: Int) -> [MonthGridItem] {
        switch mode {
        case .conventional:
            return conventionalMonthGridItems(year: year, month: month)
        case .traditional:
            return traditionalMonthGridItems(year: year, month: month)
        }
    }

    func selection(for yearRow: YearRow) -> Selection? {
        switch mode {
        case .conventional:
            guard let spread = yearRow.explicitSpread else { return nil }
            return .conventional(spread)
        case .traditional:
            guard let date = yearRow.explicitTraditionalSelection else { return nil }
            return .traditionalYear(date)
        }
    }

    func selection(for monthRow: MonthRow) -> Selection? {
        switch mode {
        case .conventional:
            guard let spread = monthRow.explicitSpread else { return nil }
            return .conventional(spread)
        case .traditional:
            guard let date = monthRow.explicitTraditionalSelection else { return nil }
            return .traditionalMonth(date)
        }
    }

    func selection(for item: MonthGridItem) -> Selection? {
        switch mode {
        case .conventional:
            switch item.kind {
            case .day(let date):
                return spreads.first(where: {
                    $0.period == .day && calendar.isDate($0.date, inSameDayAs: date)
                }).map(Selection.conventional)
            case .multiday(let spread):
                return .conventional(spread)
            }
        case .traditional:
            switch item.kind {
            case .day(let date):
                return .traditionalDay(date)
            case .multiday:
                return nil
            }
        }
    }

    func isCurrent(yearRow: YearRow, currentSpread: DataModel.Spread) -> Bool {
        calendar.component(.year, from: currentSpread.date) == yearRow.year && currentSpread.period == .year
    }

    func isCurrent(monthRow: MonthRow, currentSpread: DataModel.Spread) -> Bool {
        currentSpread.period == .month &&
        calendar.isDate(currentSpread.date, equalTo: monthRow.date, toGranularity: .month)
    }

    func isCurrent(item: MonthGridItem, currentSpread: DataModel.Spread) -> Bool {
        switch item.kind {
        case .day(let date):
            return currentSpread.period == .day && calendar.isDate(currentSpread.date, inSameDayAs: date)
        case .multiday(let spread):
            return currentSpread.period == .multiday && currentSpread.id == spread.id
        }
    }

    private func conventionalYearRows() -> [YearRow] {
        let explicitYears = Dictionary(uniqueKeysWithValues: spreads.filter { $0.period == .year }.map {
            (calendar.component(.year, from: $0.date), $0)
        })

        var allYears = Set(explicitYears.keys)
        for spread in spreads {
            let sourceDate = spread.startDate ?? spread.date
            allYears.insert(calendar.component(.year, from: sourceDate))
        }

        return allYears.sorted(by: >).map { year in
            YearRow(
                year: year,
                explicitSpread: explicitYears[year],
                isDerived: explicitYears[year] == nil,
                explicitTraditionalSelection: nil
            )
        }
    }

    private func traditionalYearRows() -> [YearRow] {
        let currentYear = calendar.component(.year, from: today)
        let maxYear = currentYear + 10
        let earliestYear = earliestTraditionalYear() ?? currentYear

        return Array(earliestYear...maxYear).sorted(by: >).map { year in
            YearRow(
                year: year,
                explicitSpread: nil,
                isDerived: false,
                explicitTraditionalSelection: yearStart(year)
            )
        }
    }

    private func conventionalMonthRows(in year: Int) -> [MonthRow] {
        let explicitMonths = Dictionary(uniqueKeysWithValues: spreads.filter {
            $0.period == .month && calendar.component(.year, from: $0.date) == year
        }.map {
            (calendar.component(.month, from: $0.date), $0)
        })

        var allMonths = Set(explicitMonths.keys)
        for spread in spreads where spread.period == .day || spread.period == .multiday {
            let sourceDate = spread.startDate ?? spread.date
            guard calendar.component(.year, from: sourceDate) == year else { continue }
            allMonths.insert(calendar.component(.month, from: sourceDate))
        }

        return allMonths.sorted().compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                return nil
            }
            return MonthRow(
                date: date,
                explicitSpread: explicitMonths[month],
                isDerived: explicitMonths[month] == nil,
                explicitTraditionalSelection: nil
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
                explicitTraditionalSelection: date
            )
        }
    }

    private func conventionalMonthGridItems(year: Int, month: Int) -> [MonthGridItem] {
        spreads
            .compactMap { spread -> MonthGridItem? in
                switch spread.period {
                case .day:
                    guard calendar.component(.year, from: spread.date) == year,
                          calendar.component(.month, from: spread.date) == month else { return nil }
                    return MonthGridItem(kind: .day(spread.date), calendar: calendar)
                case .multiday:
                    let startDate = spread.startDate ?? spread.date
                    guard calendar.component(.year, from: startDate) == year,
                          calendar.component(.month, from: startDate) == month else { return nil }
                    return MonthGridItem(kind: .multiday(spread), calendar: calendar)
                default:
                    return nil
                }
            }
            .sorted { lhs, rhs in
                if lhs.startDate == rhs.startDate {
                    return lhs.label < rhs.label
                }
                return lhs.startDate < rhs.startDate
            }
    }

    private func traditionalMonthGridItems(year: Int, month: Int) -> [MonthGridItem] {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        return dayRange.compactMap { day -> MonthGridItem? in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
                return nil
            }
            return MonthGridItem(kind: .day(date), calendar: calendar)
        }
    }

    private func earliestTraditionalYear() -> Int? {
        var years: [Int] = []

        years.append(contentsOf: spreads.map {
            calendar.component(.year, from: $0.startDate ?? $0.date)
        })
        years.append(contentsOf: tasks.map {
            calendar.component(.year, from: $0.date)
        })
        years.append(contentsOf: notes.map {
            calendar.component(.year, from: $0.date)
        })
        years.append(contentsOf: events.flatMap { event in
            [event.startDate, event.endDate].map { calendar.component(.year, from: $0) }
        })

        return years.min()
    }

    private func yearStart(_ year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }
}
