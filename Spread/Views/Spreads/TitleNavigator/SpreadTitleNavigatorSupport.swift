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
        let components = accessibilityComponents(for: selection, calendar: calendar)
        return "\(accessibilityKind)-\(components.date)-\(components.period.rawValue)"
    }

    private func accessibilityComponents(
        for selection: SpreadHeaderNavigatorModel.Selection,
        calendar: Calendar
    ) -> (date: String, period: Period) {
        switch selection {
        case .conventional(let spread):
            let date = switch spread.period {
            case .multiday:
                spread.startDate ?? spread.date
            case .year, .month, .day:
                spread.date
            }
            return (
                Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: date, calendar: calendar),
                spread.period
            )
        case .traditionalYear(let date):
            let normalized = Period.year.normalizeDate(date, calendar: calendar)
            return (
                Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: normalized, calendar: calendar),
                .year
            )
        case .traditionalMonth(let date):
            let normalized = Period.month.normalizeDate(date, calendar: calendar)
            return (
                Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: normalized, calendar: calendar),
                .month
            )
        case .traditionalDay(let date):
            let normalized = Period.day.normalizeDate(date, calendar: calendar)
            return (
                Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(from: normalized, calendar: calendar),
                .day
            )
        }
    }
}

enum TitleStripDisplayPreference: String, CaseIterable, Identifiable {
    case relevantPastOnly
    case showAllSpreads

    static let storageKey = "spreads.titleStripDisplayPreference"
    static let defaultValue: TitleStripDisplayPreference = .relevantPastOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .relevantPastOnly:
            return "Relevant Past Only"
        case .showAllSpreads:
            return "Show All Spreads"
        }
    }

    init(storedRawValue: String) {
        self = Self(rawValue: storedRawValue) ?? Self.defaultValue
    }
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

    func titleStripItems(
        for currentSelection: SpreadHeaderNavigatorModel.Selection,
        displayPreference: TitleStripDisplayPreference
    ) -> [Item] {
        let completeItems = items(for: currentSelection)
        return SpreadTitleStripRelevanceFilter.filteredItems(
            completeItems,
            mode: headerModel.mode,
            displayPreference: displayPreference,
            tasks: headerModel.tasks,
            calendar: calendar,
            today: today
        )
    }

    func item(for recommendation: SpreadTitleNavigatorRecommendation) -> Item {
        let spread = DataModel.Spread(
            period: recommendation.period,
            date: recommendation.date,
            calendar: recommendation.calendar
        )
        return item(for: spread, allowsPersonalization: false)
    }

    private func conventionalYearItems(in year: Int) -> [Item] {
        let explicitSpreadsInYear = headerModel.spreads
            .filter { spreadYear(for: $0) == year }

        return explicitSpreadsInYear
            .map { item(for: $0, allowsPersonalization: true) }
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
                badge: badge(for: .traditionalYear(yearStart(year)))
            )
        ]

        for month in 1...12 {
            let monthDate = self.monthDate(year: year, month: month)
            let monthSelection = SpreadHeaderNavigatorModel.Selection.traditionalMonth(monthDate)
            items.append(
                Item(
                    id: monthSelection.stableID(calendar: calendar),
                    label: DataModel.Spread(
                        period: .month,
                        date: monthDate,
                        calendar: calendar
                    )
                    .displayLabel(calendar: calendar),
                    selection: monthSelection,
                    style: .month,
                    display: monthDisplay(for: monthDate),
                    badge: badge(for: monthSelection)
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
                        badge: badge(for: daySelection)
                    )
                )
            }
        }

        return items.sorted(by: isEarlier)
    }

    private func item(for spread: DataModel.Spread, allowsPersonalization: Bool) -> Item {
        let selection = SpreadHeaderNavigatorModel.Selection.conventional(spread)
        return Item(
            id: selection.stableID(calendar: calendar),
            label: label(for: spread, allowsPersonalization: allowsPersonalization),
            selection: selection,
            style: style(for: spread),
            display: display(for: spread, allowsPersonalization: allowsPersonalization),
            badge: badge(for: spread, selection: selection)
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
            : overdueCount(for: selection)

        if overdueCount > 0 {
            return .overdue(count: overdueCount)
        }
        if spread.isFavorite {
            return .favorite
        }
        return nil
    }

    private func badge(for selection: SpreadHeaderNavigatorModel.Selection) -> SpreadTitleNavigatorBadge? {
        let count = overdueCount(for: selection)
        guard count > 0 else { return nil }
        return .overdue(count: count)
    }

    private func overdueCount(for selection: SpreadHeaderNavigatorModel.Selection) -> Int {
        overdueCountsBySelectionID[selection.stableID(calendar: calendar), default: 0]
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
                  task.hasPreferredAssignment,
                  taskDateFallsWithinMultidayRange(task.date, spread: spread),
                  isOverdue(date: task.date, period: task.period) else {
                return
            }
            count += 1
        }
    }

    private func taskDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard let range = multidayDateRange(for: spread) else { return false }
        let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
        return normalizedDate >= range.start && normalizedDate <= range.end
    }

    private func multidayDateRange(for spread: DataModel.Spread) -> (start: Date, end: Date)? {
        guard spread.period == .multiday else { return nil }
        let start = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: calendar)
        let end = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar)
        if start <= end {
            return (start, end)
        }
        return (end, start)
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

enum SpreadTitleStripRelevanceFilter {
    static func filteredItems(
        _ items: [SpreadTitleNavigatorModel.Item],
        mode: SpreadHeaderNavigatorModel.Mode,
        displayPreference: TitleStripDisplayPreference,
        tasks: [DataModel.Task],
        calendar: Calendar,
        today: Date
    ) -> [SpreadTitleNavigatorModel.Item] {
        guard case .conventional = mode,
              displayPreference == .relevantPastOnly else {
            return items
        }

        return items.filter { item in
            guard case .conventional(let spread) = item.selection else {
                return true
            }

            guard isPast(spread, calendar: calendar, today: today) else {
                return true
            }

            return spread.isFavorite || hasOpenTask(on: spread, tasks: tasks, calendar: calendar)
        }
    }

    static func isPast(
        _ spread: DataModel.Spread,
        calendar: Calendar,
        today: Date
    ) -> Bool {
        let todayStart = today.startOfDay(calendar: calendar)
        let periodEndBoundary: Date?

        switch spread.period {
        case .year:
            let start = Period.year.normalizeDate(spread.date, calendar: calendar)
            periodEndBoundary = calendar.date(byAdding: .year, value: 1, to: start)
        case .month:
            let start = Period.month.normalizeDate(spread.date, calendar: calendar)
            periodEndBoundary = calendar.date(byAdding: .month, value: 1, to: start)
        case .day:
            let start = Period.day.normalizeDate(spread.date, calendar: calendar)
            periodEndBoundary = calendar.date(byAdding: .day, value: 1, to: start)
        case .multiday:
            let end = multidayEffectiveEndDate(for: spread, calendar: calendar)
            periodEndBoundary = calendar.date(byAdding: .day, value: 1, to: end)
        }

        guard let periodEndBoundary else { return false }
        return periodEndBoundary <= todayStart
    }

    static func hasOpenTask(
        on spread: DataModel.Spread,
        tasks: [DataModel.Task],
        calendar: Calendar
    ) -> Bool {
        tasks.contains { task in
            guard task.status == .open else { return false }

            if spread.period == .multiday {
                return task.hasPreferredAssignment &&
                    taskDateFallsWithinMultidayRange(task.date, spread: spread, calendar: calendar)
            }

            return task.assignments.contains { assignment in
                assignment.status == .open &&
                assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
            }
        }
    }

    private static func taskDateFallsWithinMultidayRange(
        _ date: Date,
        spread: DataModel.Spread,
        calendar: Calendar
    ) -> Bool {
        guard let range = multidayDateRange(for: spread, calendar: calendar) else {
            return false
        }
        let normalizedDate = Period.day.normalizeDate(date, calendar: calendar)
        return normalizedDate >= range.start && normalizedDate <= range.end
    }

    private static func multidayEffectiveEndDate(
        for spread: DataModel.Spread,
        calendar: Calendar
    ) -> Date {
        guard let range = multidayDateRange(for: spread, calendar: calendar) else {
            return Period.day.normalizeDate(spread.date, calendar: calendar)
        }
        return range.end
    }

    private static func multidayDateRange(
        for spread: DataModel.Spread,
        calendar: Calendar
    ) -> (start: Date, end: Date)? {
        guard spread.period == .multiday else { return nil }

        let start = Period.day.normalizeDate(spread.startDate ?? spread.date, calendar: calendar)
        let end = Period.day.normalizeDate(spread.endDate ?? spread.date, calendar: calendar)

        if start <= end {
            return (start, end)
        }
        return (end, start)
    }
}

enum SpreadTitleNavigatorSelectionVisibility {
    static func isSelectionVisible(
        _ selection: SpreadHeaderNavigatorModel.Selection,
        in items: [SpreadTitleNavigatorModel.Item],
        calendar: Calendar
    ) -> Bool {
        let selectionID = selection.stableID(calendar: calendar)
        return items.contains { $0.id == selectionID }
    }
}

enum SpreadTitleNavigatorTapSupport {
    static func selectionChange(
        for item: SpreadTitleNavigatorModel.Item,
        selectedSemanticID: String
    ) -> SpreadHeaderNavigatorModel.Selection? {
        item.id == selectedSemanticID ? nil : item.selection
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
            let ymd = Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.ymd(
                from: date,
                calendar: calendar
            )
            return "traditional.day.\(ymd)"
        }
    }
}
