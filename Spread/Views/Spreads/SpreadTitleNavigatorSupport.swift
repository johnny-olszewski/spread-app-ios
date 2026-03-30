import CoreGraphics
import Foundation

struct SpreadTitleNavigatorModel {
    struct LayoutMetrics: Equatable {
        let slotWidth: CGFloat
        let horizontalInset: CGFloat
        let itemSpacing: CGFloat
    }

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
            return conventionalItems(for: spread)
        case .traditionalYear(let yearDate):
            return traditionalYearItems(for: yearDate)
        case .traditionalMonth(let monthDate):
            return traditionalMonthItems(for: monthDate)
        case .traditionalDay(let dayDate):
            return traditionalDayItems(for: dayDate)
        }
    }

    func metrics(for availableWidth: CGFloat) -> LayoutMetrics {
        let slotWidth = min(max(availableWidth * 0.28, 92), 180)
        return LayoutMetrics(
            slotWidth: slotWidth,
            horizontalInset: max((availableWidth - slotWidth) / 2, 0),
            itemSpacing: 12
        )
    }

    private func conventionalItems(for currentSpread: DataModel.Spread) -> [Item] {
        switch currentSpread.period {
        case .year:
            return headerModel.rootYears()
                .compactMap { row in
                    guard let selection = headerModel.selection(for: row) else { return nil }
                    return Item(
                        id: selection.stableID(calendar: calendar),
                        label: String(row.year),
                        selection: selection,
                        style: .year
                    )
                }
                .sorted(by: isEarlier)
        case .month:
            let year = calendar.component(.year, from: currentSpread.date)
            return headerModel.months(in: year)
                .compactMap { row in
                    guard let selection = headerModel.selection(for: row) else { return nil }
                    return Item(
                        id: selection.stableID(calendar: calendar),
                        label: DataModel.Spread(period: .month, date: row.date, calendar: calendar)
                            .displayLabel(calendar: calendar),
                        selection: selection,
                        style: .month
                    )
                }
                .sorted(by: isEarlier)
        case .day, .multiday:
            let year = calendar.component(.year, from: currentSpread.date)
            let month = calendar.component(.month, from: currentSpread.date)
            return headerModel.monthGridItems(year: year, month: month)
                .compactMap { gridItem in
                    guard let selection = headerModel.selection(for: gridItem) else { return nil }
                    return Item(
                        id: selection.stableID(calendar: calendar),
                        label: gridItem.label,
                        selection: selection,
                        style: gridItem.isMultiday ? .multiday : .day
                    )
                }
        }
    }

    private func traditionalYearItems(for currentYearDate: Date) -> [Item] {
        headerModel.rootYears()
            .compactMap { row in
                guard let selection = headerModel.selection(for: row) else { return nil }
                return Item(
                    id: selection.stableID(calendar: calendar),
                    label: String(row.year),
                    selection: selection,
                    style: .year
                )
            }
            .sorted(by: isEarlier)
    }

    private func traditionalMonthItems(for currentMonthDate: Date) -> [Item] {
        let year = calendar.component(.year, from: currentMonthDate)
        return headerModel.months(in: year)
            .compactMap { row in
                guard let selection = headerModel.selection(for: row) else { return nil }
                return Item(
                    id: selection.stableID(calendar: calendar),
                    label: DataModel.Spread(period: .month, date: row.date, calendar: calendar)
                        .displayLabel(calendar: calendar),
                    selection: selection,
                    style: .month
                )
            }
            .sorted(by: isEarlier)
    }

    private func traditionalDayItems(for currentDayDate: Date) -> [Item] {
        let year = calendar.component(.year, from: currentDayDate)
        let month = calendar.component(.month, from: currentDayDate)
        return headerModel.monthGridItems(year: year, month: month)
            .compactMap { item in
                guard let selection = headerModel.selection(for: item) else { return nil }
                return Item(
                    id: selection.stableID(calendar: calendar),
                    label: item.label,
                    selection: selection,
                    style: .day
                )
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
