import Foundation

enum SpreadTitleNavigatorItemStyle: Equatable {
    case year
    case month
    case day
    case multiday
}

struct SpreadTitleNavigatorModel {
    struct Item: Identifiable {
        struct Display: Equatable {
            let top: String?
            let bottom: String
            let footer: String?
        }

        let id: String
        let label: String
        let selection: SpreadHeaderNavigatorModel.Selection
        let style: SpreadTitleNavigatorItemStyle
        let display: Display
        let overdueCount: Int
    }

    let headerModel: SpreadHeaderNavigatorModel
    let overdueItems: [OverdueTaskItem]

    init(
        headerModel: SpreadHeaderNavigatorModel,
        overdueItems: [OverdueTaskItem] = []
    ) {
        self.headerModel = headerModel
        self.overdueItems = overdueItems
    }

    var calendar: Calendar { headerModel.calendar }
    var today: Date { headerModel.today }

    func todaySemanticID(for currentSelection: SpreadHeaderNavigatorModel.Selection) -> String? {
        switch currentSelection {
        case .conventional:
            let organizer = SpreadHierarchyOrganizer(
                spreads: headerModel.spreads,
                calendar: calendar
            )
            guard let spread = organizer.initialSelection(for: today) else { return nil }
            return SpreadHeaderNavigatorModel.Selection
                .conventional(spread)
                .stableID(calendar: calendar)
        case .traditionalYear, .traditionalMonth, .traditionalDay:
            return SpreadHeaderNavigatorModel.Selection
                .traditionalDay(Period.day.normalizeDate(today, calendar: calendar))
                .stableID(calendar: calendar)
        }
    }

    func items(for currentSelection: SpreadHeaderNavigatorModel.Selection) -> [Item] {
        switch currentSelection {
        case .conventional(let spread):
            return conventionalYearItems(in: calendar.component(.year, from: spread.startDate ?? spread.date))
        case .traditionalYear(let yearDate):
            return traditionalYearItems(in: calendar.component(.year, from: yearDate))
        case .traditionalMonth(let monthDate):
            return traditionalYearItems(in: calendar.component(.year, from: monthDate))
        case .traditionalDay(let dayDate):
            return traditionalYearItems(in: calendar.component(.year, from: dayDate))
        }
    }

    func item(for recommendation: SpreadTitleNavigatorRecommendation) -> Item {
        let spread = DataModel.Spread(
            period: recommendation.period,
            date: recommendation.date,
            calendar: recommendation.calendar
        )
        return item(for: spread)
    }

    private func conventionalYearItems(in year: Int) -> [Item] {
        let explicitSpreadsInYear = headerModel.spreads
            .filter { spreadYear(for: $0) == year }

        return explicitSpreadsInYear
            .map(item(for:))
            .sorted(by: isEarlier)
    }

    private func traditionalYearItems(in year: Int) -> [Item] {
        var items: [Item] = [
            Item(
                id: SpreadHeaderNavigatorModel.Selection.traditionalYear(yearStart(year)).stableID(calendar: calendar),
                label: String(year),
                selection: .traditionalYear(yearStart(year)),
                style: .year,
                display: yearDisplay(for: year),
                overdueCount: overdueCount(for: .traditionalYear(yearStart(year)))
            )
        ]

        for month in 1...12 {
            let monthDate = self.monthDate(year: year, month: month)
            let monthSelection = SpreadHeaderNavigatorModel.Selection.traditionalMonth(monthDate)
            items.append(
                Item(
                    id: monthSelection.stableID(calendar: calendar),
                    label: DataModel.Spread(period: .month, date: monthDate, calendar: calendar).displayLabel(calendar: calendar),
                    selection: monthSelection,
                    style: .month,
                    display: monthDisplay(for: monthDate),
                    overdueCount: overdueCount(for: monthSelection)
                )
            )

            let range = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<1
            for day in range {
                let dayDate = self.dayDate(year: year, month: month, day: day)
                let daySelection = SpreadHeaderNavigatorModel.Selection.traditionalDay(dayDate)
                items.append(
                    Item(
                        id: daySelection.stableID(calendar: calendar),
                        label: String(day),
                        selection: daySelection,
                        style: .day,
                        display: dayDisplay(for: dayDate),
                        overdueCount: overdueCount(for: daySelection)
                    )
                )
            }
        }

        return items.sorted(by: isEarlier)
    }

    private func item(for spread: DataModel.Spread) -> Item {
        let selection = SpreadHeaderNavigatorModel.Selection.conventional(spread)
        return Item(
            id: selection.stableID(calendar: calendar),
            label: label(for: spread),
            selection: selection,
            style: style(for: spread),
            display: display(for: spread),
            overdueCount: overdueCount(for: selection)
        )
    }

    private func label(for spread: DataModel.Spread) -> String {
        switch spread.period {
        case .year:
            return String(calendar.component(.year, from: spread.date))
        case .month, .day, .multiday:
            return spread.displayLabel(calendar: calendar)
        }
    }

    private func style(for spread: DataModel.Spread) -> SpreadTitleNavigatorItemStyle {
        switch spread.period {
        case .year:
            return .year
        case .month:
            return .month
        case .day:
            return .day
        case .multiday:
            return .multiday
        }
    }

    private func display(for spread: DataModel.Spread) -> Item.Display {
        switch spread.period {
        case .year:
            return yearDisplay(for: calendar.component(.year, from: spread.date))
        case .month:
            return monthDisplay(for: spread.date)
        case .day:
            return dayDisplay(for: spread.date)
        case .multiday:
            return multidayDisplay(for: spread)
        }
    }

    private func yearDisplay(for year: Int) -> Item.Display {
        let yearString = String(year)
        let prefix = String(yearString.prefix(max(yearString.count - 2, 0)))
        let suffix = String(yearString.suffix(2))
        return .init(top: prefix.isEmpty ? nil : prefix, bottom: suffix, footer: nil)
    }

    private func monthDisplay(for date: Date) -> Item.Display {
        .init(top: nil, bottom: monthAbbreviation(for: date), footer: nil)
    }

    private func dayDisplay(for date: Date) -> Item.Display {
        .init(
            top: monthAbbreviation(for: date).uppercased(),
            bottom: String(calendar.component(.day, from: date)),
            footer: weekdayAbbreviation(for: date).uppercased()
        )
    }

    private func multidayDisplay(for spread: DataModel.Spread) -> Item.Display {
        let startDate = spread.startDate ?? spread.date
        let endDate = spread.endDate ?? spread.date
        let startMonth = monthAbbreviation(for: startDate).uppercased()
        let endMonth = monthAbbreviation(for: endDate).uppercased()
        let topLine = startMonth == endMonth ? startMonth : "\(startMonth)-\(endMonth)"
        let bottomLine = "\(calendar.component(.day, from: startDate))-\(calendar.component(.day, from: endDate))"
        let startWeekday = weekdayAbbreviation(for: startDate).uppercased()
        let endWeekday = weekdayAbbreviation(for: endDate).uppercased()
        let footerLine = startWeekday == endWeekday ? startWeekday : "\(startWeekday)-\(endWeekday)"
        return .init(top: topLine, bottom: bottomLine, footer: footerLine)
    }

    private func monthAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    private func weekdayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func spreadYear(for spread: DataModel.Spread) -> Int {
        calendar.component(.year, from: spread.startDate ?? spread.date)
    }

    private func monthDate(year: Int, month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    private func dayDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func yearStart(_ year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }

    private func overdueCount(for selection: SpreadHeaderNavigatorModel.Selection) -> Int {
        overdueCountsBySelectionID[selection.stableID(calendar: calendar), default: 0]
    }

    private var overdueCountsBySelectionID: [String: Int] {
        overdueItems.reduce(into: [:]) { counts, item in
            guard let selectionID = selectionID(for: item.sourceKey) else { return }
            counts[selectionID, default: 0] += 1
        }
    }

    private func selectionID(for sourceKey: TaskReviewSourceKey) -> String? {
        switch sourceKey.kind {
        case .inbox:
            return nil
        case .spread(let id, let period, let date):
            switch headerModel.mode {
            case .conventional:
                guard let spread = headerModel.spreads.first(where: { $0.id == id }) else { return nil }
                return SpreadHeaderNavigatorModel.Selection
                    .conventional(spread)
                    .stableID(calendar: calendar)
            case .traditional:
                switch period {
                case .year:
                    return SpreadHeaderNavigatorModel.Selection
                        .traditionalYear(Period.year.normalizeDate(date, calendar: calendar))
                        .stableID(calendar: calendar)
                case .month:
                    return SpreadHeaderNavigatorModel.Selection
                        .traditionalMonth(Period.month.normalizeDate(date, calendar: calendar))
                        .stableID(calendar: calendar)
                case .day:
                    return SpreadHeaderNavigatorModel.Selection
                        .traditionalDay(Period.day.normalizeDate(date, calendar: calendar))
                        .stableID(calendar: calendar)
                case .multiday:
                    return nil
                }
            }
        }
    }

    private func isEarlier(_ lhs: Item, _ rhs: Item) -> Bool {
        let lhsKey = sortKey(for: lhs.selection)
        let rhsKey = sortKey(for: rhs.selection)
        if lhsKey.date == rhsKey.date {
            return lhsKey.rank < rhsKey.rank
        }
        return lhsKey.date < rhsKey.date
    }

    private func sortKey(for selection: SpreadHeaderNavigatorModel.Selection) -> (date: Date, rank: Int) {
        switch selection {
        case .conventional(let spread):
            let rank: Int = switch spread.period {
            case .year: 0
            case .month: 1
            case .multiday: 2
            case .day: 3
            }
            return (spread.startDate ?? spread.date, rank)
        case .traditionalYear(let date):
            return (Period.year.normalizeDate(date, calendar: calendar), 0)
        case .traditionalMonth(let date):
            return (Period.month.normalizeDate(date, calendar: calendar), 1)
        case .traditionalDay(let date):
            return (Period.day.normalizeDate(date, calendar: calendar), 2)
        }
    }
}

extension SpreadTitleNavigatorModel {
    func liveWindowIDs(
        items: [Item],
        anchorID: String,
        radius: Int = 2
    ) -> Set<String> {
        guard let anchorIndex = items.firstIndex(where: { $0.id == anchorID }) else {
            return Set(items.prefix(radius * 2 + 1).map(\.id))
        }

        let lowerBound = max(0, anchorIndex - radius)
        let upperBound = min(items.count - 1, anchorIndex + radius)
        return Set(items[lowerBound...upperBound].map(\.id))
    }
}

extension SpreadHeaderNavigatorModel.Selection {
    func stableID(calendar: Calendar) -> String {
        switch self {
        case .conventional(let spread):
            return "conventional.\(spread.id.uuidString.lowercased())"
        case .traditionalYear(let date):
            return "traditional.year.\(calendar.component(.year, from: date))"
        case .traditionalMonth(let date):
            let components = calendar.dateComponents([.year, .month], from: date)
            return String(format: "traditional.month.%04d-%02d", components.year ?? 0, components.month ?? 0)
        case .traditionalDay(let date):
            return "traditional.day.\(Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: date, calendar: calendar))"
        }
    }
}
