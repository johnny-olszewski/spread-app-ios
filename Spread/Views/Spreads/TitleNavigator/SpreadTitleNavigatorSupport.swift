import Foundation
import SwiftUI

enum SpreadTitleNavigatorItemStyle: Equatable {
    case year
    case month
    case day
    case multiday
}

enum SpreadTitleNavigatorBadge: Equatable {
    case overdue(count: Int)
    case favorite

    var accessibilityKind: String {
        switch self {
        case .overdue:
            return "overdue"
        case .favorite:
            return "favorite"
        }
    }

    func accessibilityLabel(style: SpreadTitleNavigatorItemStyle) -> String {
        switch self {
        case .overdue(let count):
            let noun = count == 1 ? "task" : "tasks"
            if style == .multiday {
                return "\(count) overdue \(noun) in this date range"
            }
            return "\(count) overdue \(noun)"
        case .favorite:
            return "Favorited spread"
        }
    }

    func accessibilityIdentifier(
        for selection: SpreadHeaderNavigatorModel.Selection,
        calendar: Calendar
    ) -> String {
        let date: Date = selection.period == .multiday
            ? (selection.startDate ?? selection.date)
            : selection.date
        let ymd = Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: date, calendar: calendar)
        return "\(accessibilityKind)-\(ymd)-\(selection.period.rawValue)"
    }
}

/// Label content for the compact spread context bar.
struct SpreadCompactBarLabel: Equatable {
    let primary: String
    let secondary: String?
}

struct SpreadTitleNavigatorModel {
    struct Item: Identifiable {
        struct Display: Equatable {
            let top: String?
            let bottom: String
            let footer: String?
            var isPersonalized: Bool = false
        }

        let id: String
        let label: String
        let selection: SpreadHeaderNavigatorModel.Selection
        let style: SpreadTitleNavigatorItemStyle
        let display: Display
        let badge: SpreadTitleNavigatorBadge?
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
        guard let spread = headerModel.spreads.bestSpread(for: today, calendar: calendar) else { return nil }
        return spread.stableID(calendar: calendar)
    }

    func items(for currentSelection: SpreadHeaderNavigatorModel.Selection) -> [Item] {
        conventionalYearItems(in: calendar.component(.year, from: currentSelection.startDate ?? currentSelection.date))
    }

    func item(for recommendation: SpreadTitleNavigatorRecommendation) -> Item {
        let spread = DataModel.Spread(
            period: recommendation.period,
            date: recommendation.date,
            calendar: recommendation.calendar
        )
        return item(for: spread, allowsPersonalization: false)
    }

    /// Compact primary + optional secondary label for the persistent context bar.
    func compactBarLabel(for selection: SpreadHeaderNavigatorModel.Selection) -> SpreadCompactBarLabel {
        let name = displayName(for: selection, allowsPersonalization: true)
        return SpreadCompactBarLabel(primary: name.primary, secondary: name.secondaryForHeader)
    }

    private func conventionalYearItems(in year: Int) -> [Item] {
        let explicitSpreadsInYear = headerModel.spreads
            .filter { spreadYear(for: $0) == year }

        return explicitSpreadsInYear
            .map { item(for: $0, allowsPersonalization: true) }
            .sorted(by: isEarlier)
    }

    private func item(for spread: DataModel.Spread, allowsPersonalization: Bool) -> Item {
        Item(
            id: spread.stableID(calendar: calendar),
            label: label(for: spread, allowsPersonalization: allowsPersonalization),
            selection: spread,
            style: style(for: spread),
            display: display(for: spread, allowsPersonalization: allowsPersonalization),
            badge: badge(for: spread, selection: spread)
        )
    }

    private func label(for spread: DataModel.Spread, allowsPersonalization: Bool) -> String {
        let displayName = displayName(for: spread, allowsPersonalization: allowsPersonalization)
        if displayName.isPersonalized {
            return displayName.primary
        }

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

    private func display(for spread: DataModel.Spread, allowsPersonalization: Bool) -> Item.Display {
        let displayName = displayName(for: spread, allowsPersonalization: allowsPersonalization)
        if displayName.isPersonalized {
            return personalizedDisplay(for: spread, name: displayName.primary)
        }

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

    private func displayName(for spread: DataModel.Spread, allowsPersonalization: Bool) -> SpreadDisplayName {
        SpreadDisplayNameFormatter(
            calendar: calendar,
            today: today,
            firstWeekday: headerModel.firstWeekday
        )
        .display(for: spread, allowsPersonalization: allowsPersonalization)
    }

    private func personalizedDisplay(for spread: DataModel.Spread, name: String) -> Item.Display {
        switch spread.period {
        case .year:
            return .init(
                top: String(calendar.component(.year, from: spread.date)),
                bottom: name,
                footer: nil,
                isPersonalized: true
            )
        case .month:
            return .init(
                top: monthAbbreviation(for: spread.date),
                bottom: name,
                footer: String(calendar.component(.year, from: spread.date)),
                isPersonalized: true
            )
        case .day:
            return .init(
                top: dayMonthHeader(for: spread.date),
                bottom: name,
                footer: weekdayAbbreviation(for: spread.date),
                isPersonalized: true
            )
        case .multiday:
            return .init(
                top: compactDateRange(for: spread),
                bottom: name,
                footer: weekdayRange(for: spread),
                isPersonalized: true
            )
        }
    }

    private func yearDisplay(for year: Int) -> Item.Display {
        let yearString = String(year)
        let prefix = String(yearString.prefix(max(yearString.count - 2, 0)))
        let suffix = String(yearString.suffix(2))
        return .init(top: prefix.isEmpty ? nil : prefix, bottom: suffix, footer: nil)
    }

    private func monthDisplay(for date: Date) -> Item.Display {
        .init(
            top: String(calendar.component(.year, from: date)),
            bottom: monthAbbreviation(for: date).uppercased(),
            footer: nil
        )
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
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    private func weekdayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    private func dayMonthHeader(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func compactDateRange(for spread: DataModel.Spread) -> String {
        let startDate = spread.startDate ?? spread.date
        let endDate = spread.endDate ?? spread.date
        let startMonth = monthAbbreviation(for: startDate)
        let endMonth = monthAbbreviation(for: endDate)
        let startDay = calendar.component(.day, from: startDate)
        let endDay = calendar.component(.day, from: endDate)

        if startMonth == endMonth {
            return "\(startMonth) \(startDay)-\(endDay)"
        }
        return "\(startMonth) \(startDay)-\(endMonth) \(endDay)"
    }

    private func weekdayRange(for spread: DataModel.Spread) -> String {
        let startDate = spread.startDate ?? spread.date
        let endDate = spread.endDate ?? spread.date
        let startWeekday = weekdayAbbreviation(for: startDate)
        let endWeekday = weekdayAbbreviation(for: endDate)
        if startWeekday == endWeekday {
            return startWeekday
        }
        return "\(startWeekday)-\(endWeekday)"
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

    private func badge(
        for spread: DataModel.Spread,
        selection: SpreadHeaderNavigatorModel.Selection
    ) -> SpreadTitleNavigatorBadge? {
        let overdueCount = spread.period == .multiday
            ? multidayOverdueCount(for: spread)
            : overdueCount(for: spread)

        if overdueCount > 0 {
            return .overdue(count: overdueCount)
        }
        if spread.isFavorite {
            return .favorite
        }
        return nil
    }

    private func overdueCount(for spread: SpreadHeaderNavigatorModel.Selection) -> Int {
        overdueCountsBySelectionID[spread.stableID(calendar: calendar), default: 0]
    }

    private var overdueCountsBySelectionID: [String: Int] {
        overdueItems.reduce(into: [:]) { counts, item in
            guard item.task.status == .open else { return }
            guard let selectionID = selectionID(for: item.sourceKey) else { return }
            counts[selectionID, default: 0] += 1
        }
    }

    private func multidayOverdueCount(for spread: DataModel.Spread) -> Int {
        headerModel.tasks.reduce(into: 0) { count, task in
            guard task.status == .open,
                  task.assignments.contains(where: { assignment in
                      assignment.status == .open &&
                      assignment.matches(spread: spread, calendar: calendar)
                  }),
                  isOverdue(
                    date: Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar),
                    period: .day
                  ) else {
                return
            }
            count += 1
        }
    }

    private func isOverdue(date: Date, period: Period) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)

        switch period {
        case .day:
            return todayStart > date.startOfDay(calendar: calendar)
        case .month:
            let startOfMonth = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                return false
            }
            return todayStart >= startOfNextMonth
        case .year:
            let startOfYear = period.normalizeDate(date, calendar: calendar)
            guard let startOfNextYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else {
                return false
            }
            return todayStart >= startOfNextYear
        case .multiday:
            return false
        }
    }

    private func selectionID(for sourceKey: TaskReviewSourceKey) -> String? {
        switch sourceKey.kind {
        case .inbox:
            return nil
        case .spread(let id, _, _):
            guard let spread = headerModel.spreads.first(where: { $0.id == id }) else { return nil }
            return spread.stableID(calendar: calendar)
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
        let rank: Int = switch selection.period {
        case .year: 0
        case .month: 1
        case .multiday: 2
        case .day: 3
        }
        return (selection.startDate ?? selection.date, rank)
    }
}

enum SpreadNavigatorPresentationSupport {
    static func presentsAsPopover(horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
        horizontalSizeClass == .regular
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

extension DataModel.Spread {
    func stableID(calendar: Calendar) -> String {
        "spread.\(id.uuidString.lowercased())"
    }
}
