import Foundation

struct SpreadTitleNavigatorModel {
    struct Item: Identifiable {
        enum Style: Equatable {
            case year
            case month
            case day
            case multiday
        }

        let id: String
        let label: String
        let selection: SpreadHeaderNavigatorModel.Selection
        let style: Style
    }

    let headerModel: SpreadHeaderNavigatorModel

    var calendar: Calendar { headerModel.calendar }

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
                style: .year
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
                    style: .month
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
                        style: .day
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
            style: style(for: spread)
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

    private func style(for spread: DataModel.Spread) -> Item.Style {
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
            case .day: 2
            case .multiday: 3
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
